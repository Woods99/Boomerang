//
//  DataHolder.swift
//  Boomerang
//
//  Created by Stefano Mondino on 19/01/2019.
//  Copyright © 2019 Synesthesia. All rights reserved.
//

import Foundation
import RxSwift

public typealias DataUpdate = () -> ([IndexPath])
typealias ViewModelCache = GroupCache<IdentifiableViewModelType>

public enum DataHolderUpdate {
    case reload(DataUpdate)
    case deleteItems(DataUpdate)
    case deleteSections(DataUpdate)
    case insertItems(DataUpdate)
    case insertSections(DataUpdate)
    case move(DataUpdate)
    case none
}
/**
 Defines how elements should be inserted in data holder. Temporary unimplemented
 */
typealias DataHolderUpdateCustomStrategy = (DataHolder) -> (Observable<DataHolderUpdate>)
enum DataHolderUpdateStrategy {
    case reload
    case insert
    case timedInsert
    case custom(DataHolderUpdateCustomStrategy)
}

public class DataHolder {
    public var groups: Observable<DataGroup> {
        return self._modelGroup.asObservable().do(onNext: {[weak self] _ in
            self?.itemCache.clear()
        })
    }
    
    public var isLoading: Observable<Bool> {
        return action.executing
    }
    public var errors: Observable<Error> {
        return  action.errors.map {
            switch $0 {
            case.underlyingError(let e): return e
            default: return nil
            }
            }
            .flatMap { Observable.from(optional: $0)}
        
    }
    
    public fileprivate(set) var modelGroup: DataGroup {
        get { return (try? _modelGroup.value()) ?? .empty }
        set { _modelGroup.onNext(newValue)}
    }
    
    internal var itemCache: ViewModelCache = ViewModelCache()
    
    public var useCache: Bool {
        get {
            return self.itemCache.isEnabled
        }
        set {
            self.itemCache.isEnabled = newValue
        }
    }
    
    internal let updates: BehaviorSubject<DataHolderUpdate> = BehaviorSubject(value: .none)
    
    internal let disposeBag = DisposeBag()
    private var action: Action<Void, DataHolderUpdate> = Action {_ in .empty()}
    private let _modelGroup: BehaviorSubject<DataGroup> = BehaviorSubject(value: DataGroup.empty)
    private let interrupt: BehaviorSubject<()>
    
    public init() {
        action = Action { .empty() }
        interrupt = BehaviorSubject(value: ())
    }
    public init(data: Observable<DataGroup>, cancelWith interrupt: BehaviorSubject<()> = BehaviorSubject(value: ())) {
        let strategy: DataHolderUpdateStrategy = .reload
        self.interrupt = interrupt
        self.action = Action { [weak self] in
            guard let self = self else { return .empty() }
            return data
                .takeUntil(interrupt.skip(1))
                .flatMapLatest {[weak self] group -> Observable<DataHolderUpdate>in
                    switch strategy {
                    case .reload:
                        return .just(DataHolderUpdate.reload( {[weak self] in
                            return self?.reload(group) ?? []
                        }))
//                    case .insert:
//                        return Observable.just(DataHolderUpdate.insertItems( {
//                            self._insert(group.data, at: self.modelGroup.indices.last ?? IndexPath(indexes: (0..<group.depth).map {_ in 0 }))
//                        })).startWith(.reload( { self.reload(DataGroup.empty) }))
                    default: return .empty()
                    }
            }
        }
//
//        self.action
//            .elements
//            .bind(to: _modelGroup)
//            .disposed(by: disposeBag)
        
        self.action.elements
            .bind(to: updates)
            .disposed(by: disposeBag)
    }
    
    public func cancel() {
        self.interrupt.onNext(())
    }
    
    public func start() {
        self.action.execute(())
    }
}

extension DataHolder: MutableCollection, RandomAccessCollection {
    public subscript(position: Index) -> Element {
        get {
            return modelGroup[position]
        }
        set {
            var group = modelGroup
            group[position] = newValue
            _modelGroup.onNext(group)
        }
    }
    
    public typealias Element = DataGroup.Element
    public typealias Index = DataGroup.Index
//    public typealias SubSequence = DataGroup.SubSequence
    
    public var startIndex: DataGroup.Index {
        return self.modelGroup.startIndex
    }
    
    public var endIndex: DataGroup.Index {
        return self.modelGroup.endIndex
    }
    
    public func index(after i: DataHolder.Index) -> DataHolder.Index {
        return modelGroup.index(after: i)
    }
    public func index(before i: DataHolder.Index) -> DataHolder.Index {
        return modelGroup.index(before: i)
    }
}

extension DataHolder {
    public func reload(_ group: DataGroup) -> [IndexPath] {
        self.modelGroup = group
        self.itemCache.clear()
        return group.indices.map { $0 }
    }
    
    private func _insert(_ data: [DataType], at indexPath: IndexPath) -> [IndexPath] {
        guard let newIndexPath = self.modelGroup.insert(data, at: indexPath.suffix(self.modelGroup.depth)) else {
            return []
        }
        let lastIndex: Int = data.count + (newIndexPath.last ?? 0)
        let firstIndex = newIndexPath.last ?? 0
        itemCache.insertItems(data.map { _ in nil }, at: indexPath)
        return (firstIndex..<lastIndex).map {
             indexPath.dropLast().appending($0)
        }
    }
    
    private func _insertGroups(_ groups: [DataGroup], at indexPath: IndexPath) -> [IndexPath] {
        
        let oldIndices = self.indices.filter { $0.dropLast() >= indexPath && $0 < self.endIndex }
        
        guard let newIndexPath = self.modelGroup.insert(groups, at: indexPath.prefix(self.modelGroup.depth - 1)) else {
            return []
        }
        let lastIndex: Int = groups.count + (newIndexPath.last ?? 0)
        let firstIndex = newIndexPath.last ?? 0
        oldIndices
        .reversed()
            .forEach { i in
            let item = itemCache.cacheItem(at: i)
            itemCache.removeItem(at: i)
            let diff = Swift.max(1, i.count - indexPath.count)
            let last = i.suffix(diff)
                let current = i.dropLast(diff).last ?? 0
            let section = current + groups.count
            let newIndex = indexPath.dropLast().appending(section).appending(last)
                
            print("MOVING \(item?.mainItem?.identifier.name ?? "-") FROM \(i) TO NEW INDEX \(newIndex)")
            itemCache.replaceCacheItem(item, at: newIndex)
        }
        return (firstIndex..<lastIndex).map {
            let indexPath = indexPath.dropLast().appending($0)
//            self.itemCache.replaceItem(nil, at: indexPath)
            return indexPath
        }
    }
    
    public func insert(_ data: [DataType], at indexPath: IndexPath, immediate: Bool = false) {
        let insertion: DataUpdate = {[weak self] in
            guard let self = self else { return [] }
            return self._insert(data, at: indexPath)
        }
        if immediate {
            _ = insertion()
        } else {
            self.updates.onNext(.insertItems(insertion))
        }
    }
    
    public func insertGroups(_ groups: [DataGroup], at indexPath: IndexPath, immediate: Bool = false) {
          let insertion: DataUpdate = {[weak self] in
              guard let self = self else { return [] }
              return self._insertGroups(groups, at: indexPath)
          }
          if immediate {
              _ = insertion()
          } else {
              self.updates.onNext(.insertSections(insertion))
          }
      }
    
    public func delete(at indexPaths:[IndexPath], immediate: Bool = false) {
        let delete: DataUpdate = {[weak self] in
            guard let self = self else { return [] }
            let deletedIndexPaths = self.modelGroup.delete(at: indexPaths).compactMap {
                $0.value != nil ? $0.key : nil
            }
            deletedIndexPaths.forEach {
                self.itemCache.removeItem(at: $0)
//                self.itemCache.replaceItem(nil, at: $0)
//                self.itemCache.replaceSupplementaryItem(nil, at: $0, for: nil)
            }
            return deletedIndexPaths
        }
        if immediate {
            _ = delete()
        } else {
            self.updates.onNext(.deleteItems(delete))
        }
    }
    
    public func deleteGroups(at indexPaths:[IndexPath], immediate: Bool = false) {
        let delete: DataUpdate = {[weak self] in
            guard let self = self else { return [] }
            let deletedIndexPaths = self.modelGroup.deleteGroups(at: indexPaths).compactMap {
                $0.value != nil ? $0.key : nil
            }
            //TODO
            let delete = Set(deletedIndexPaths)
            self.itemCache.indices.reversed().forEach {
                if delete.contains($0.dropLast()) {
                    self.itemCache.replaceItem(nil, at: $0)
                    //self.itemCache.removeItem(at: $0)
                }
            }
//            self.itemCache.clear()
//            deletedIndexPaths.forEach {
//                self.itemCache.replaceItem(nil, at: $0)
//                self.itemCache.replaceSupplementaryItem(nil, at: $0, for: nil)
//            }
            return deletedIndexPaths
        }
        if immediate {
            _ = delete()
        } else {
            self.updates.onNext(.deleteSections(delete))
        }
    }
    
    public func moveItem(from: IndexPath, to:IndexPath, immediate: Bool = false) {
        let move: DataUpdate = {[weak self] in
            guard let self = self else { return [] }
            self.modelGroup.move(from: from, to: to)
            //Probably there's a bug here: cache should recalculate every item.
            let tmp = self.itemCache.mainItem(at: from)
            if to > from {
                self.itemCache.removeItem(at: from)
                self.itemCache.insertItem(item: tmp, at: to)
            } else {
                self.itemCache.insertItem(item: tmp, at: to)
                 self.itemCache.removeItem(at: from)
            }
            
//            self.itemCache.replaceItem(self.itemCache.mainItem(at: to), at: from)
//            self.itemCache.replaceItem(tmp, at: to)
            
            return []
        }
        if immediate {
            _ = move()
        } else {
            self.updates.onNext(.move(move))
        }
    }
}

extension DataHolder {
    func supplementaryItem(at indexPath: IndexPath, for type: String) -> DataType? {
        return modelGroup.supplementaryData(at: indexPath, for: type)
    }
}
