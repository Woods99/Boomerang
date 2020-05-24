//
//  ShowViewController.swift
//  App
//

import UIKit
import Boomerang
import UIKitBoomerang
import RxBoomerang
import RxSwift
import RxCocoa

class ShowsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var viewModel: ShowsViewModel
    
    var collectionViewDataSource: CollectionViewDataSource? {
        didSet {
            self.collectionView.dataSource = collectionViewDataSource
            self.collectionView.reloadData()
        }
    }
    
    var collectionViewDelegate: CollectionViewDelegate? {
        didSet {
            self.collectionView.delegate = collectionViewDelegate
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    var disposeBag = DisposeBag()
    private let collectionViewCellFactory: CollectionViewCellFactory
    
    init(nibName: String?,
         bundle: Bundle? = nil,
         viewModel: ShowsViewModel,
         collectionViewCellFactory: CollectionViewCellFactory) {
        self.viewModel = viewModel
        self.collectionViewCellFactory = collectionViewCellFactory
        super.init(nibName: nibName, bundle: bundle)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = viewModel.title
        let viewModel = self.viewModel
        let collectionViewDataSource = CollectionViewDataSource(viewModel: viewModel,
                                                                factory: collectionViewCellFactory)
                                                            
        let spacing: CGFloat = 4
        let sizeCalculator = AutomaticCollectionViewSizeCalculator(viewModel: viewModel,
                                                                   factory: collectionViewCellFactory, itemsPerLine: 3)
            .withItemSpacing { _, _ in return spacing }
            .withLineSpacing { _, _ in return spacing }
            .withInsets { _, _ in return UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing) }
            
        
        let collectionViewDelegate = CollectionViewDelegate(sizeCalculator: sizeCalculator)
            .withSelect { viewModel.selectItem(at: $0) }
        
        collectionView.backgroundColor = .clear

        collectionView.rx
            .animated(by: viewModel, dataSource: collectionViewDataSource)
            .disposed(by: disposeBag)
        
        self.collectionViewDelegate = collectionViewDelegate        
        
        viewModel.routes
            .bind(to: self.rx.routes())
            .disposed(by: disposeBag)
        
        viewModel.reload()
        
    }
}