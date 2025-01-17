//
//  DependencyContainer.swift
//  Boomerang
//
//  Created by Stefano Mondino on 08/11/2019.
//  Copyright © 2019 Synesthesia. All rights reserved.
//

import Foundation
/**
 Defines the ability of storing and lately resolving dependencies identified by a single key
 */
public protocol DependencyContainer: AnyObject {
    /// The container's key type. Must be `Hashable`.
    associatedtype DependencyKey: Hashable
    /// A container object
    var container: Container<DependencyKey> { get }
}
/**
 An object capable of storing dependencies and lately retrieve them according to unique keys
 
 Usually it simply needs to be instantiated in a `DependencyContainer` context,
 providing the key type (`DependencyKey` generic type)
 */
public class Container<DependencyKey: Hashable> {

    struct Dependency {
        let scope: Scope
        let closure: () -> Any
    }
    /**
        The scope of a dependency
     
        Dependencies are closures generating objects.
     
        When a dependency is resolved by a dependency container, the default behavior is to re-execute the dependency closure, thus generating a new resulting object.
        In some cases, the resulting object must be stored and retrieved lately, without being generating twice (like in the singleton pattern).
        `Scope` helps deciding which behavior must be adopted.
     */
    public enum Scope {
        /// Dependency closure is executed for each resolution. Resulting object is always a new instance
        case unique
        /// Dependency closure is executed only at first resolution. Resulting object is cached and returned for each subsequent call, instead of re-executing the closure.
        case singleton
        /// Dependency closure is executed immediately upon registration. Resulting object is cached and returned for each subsequent call, instead of re-executing the closure.
        case eagerSingleton
    }

    fileprivate var dependencies: [DependencyKey: Dependency] = [:]
    fileprivate var singletons: [DependencyKey: Any] = [:]

    public init() {}
}
public extension DependencyContainer {
    /**
        Register a new dependency in the container for given key and scope.
     
        A dependency is simply a closure producing some kind of value.
     
         Register a dependency on an already used key **overwrites** previous closure value. If a `.singleton` or `.eagerSingleton` scope was used, the cached value is cleared.
     
        Examples:
     
        - `dependencyContainer.register(for: "firstName", scope: .unique) { "John Doe" }`
     
        - `dependencyContainer.register(for: "birthdate", scope: .singleton) { Date() }`
    
     
        - Parameter key: the unique key that will be used inside the container to identify the dependency.
     
        - Parameter scope: the scope of the dependency. Defaults to `Container.Scope.unique`
     
        - Parameter handler: the dependency that will be *resolved* lately, eventually producing a `Value` result.
     
     */
    func register<Value: Any>(for key: DependencyKey,
                              scope: Container<DependencyKey>.Scope = .unique,
                              handler: @escaping () -> Value) {
        container.singletons[key] = nil
        container.dependencies[key] = Container<DependencyKey>.Dependency(scope: scope, closure: handler)
        switch scope {
        case .eagerSingleton: _ = self.resolve(key) as Value?
        default: break
        }
    }

    /**
        Resolves a dependency against provided key
     
        Resolving a dependency generally means to execute previously registered closure in order to generate some `Value` object.
     
        If previous closure was registered with a `eagerSingleton` scope, the closure will not be executed and cached value will be immediately returned.
        
        If previous closure was registered with a `singleton` scope, the closure will only be executed once.
     
        If provided key was never registered, `nil` is immediately returned
     
        - Parameter key: the key to resolve.
        
        - Returns: a value resulting from dependency resolution.
     */
    func resolve<Value: Any>(_ key: DependencyKey) -> Value? {
        guard let dependency = container.dependencies[key] else { return nil }
        switch dependency.scope {
        case .unique: return dependency.closure() as? Value
        case .singleton, .eagerSingleton: guard let value = container.singletons[key] else {
            let newValue = dependency.closure()
            container.singletons[key] = newValue
            return newValue as? Value
        }
        return value as? Value
        }
    }
}
public extension DependencyContainer {
    /**
    Shorthand for `resolve` method.
     
     - Warning: if key is not registered, a `fatalError` is thrown.
    */
    subscript<T>(index: DependencyKey) -> T {
        guard let element: T = resolve(index) else {
            fatalError("No dependency found for \(index)")
        }
        return element
    }
}

public typealias ObjectContainer = Container<ObjectIdentifier>

public extension DependencyContainer where DependencyKey == ObjectIdentifier {
    func register<Value: Any>(for key: Value.Type = Value.self,
                              scope: Container<DependencyKey>.Scope = .unique,
                              handler: @escaping () -> Value) {
        self.register(for: ObjectIdentifier(key), scope: scope, handler: handler)
    }
    func resolve<Value: Any>(_ key: Value.Type = Value.self) -> Value? {
        resolve(ObjectIdentifier(key))
    }
    
    subscript<T>(index: T.Type) -> T? {
        guard let element: T = resolve(ObjectIdentifier(index)) else {
            return nil
        }
        return element
    }
}
