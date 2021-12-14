//
//  ViewController+Rx.swift
//  RxBoomerang
//
//  Created by Stefano Mondino on 12/12/2019.
//  Copyright © 2019 Synesthesia. All rights reserved.
//
#if os(iOS) || os(tvOS)

import UIKit
import RxSwift
import RxCocoa

#if !COCOAPODS_RXBOOMERANG
import Boomerang
#endif

public extension Reactive where Base: UIViewController {
    func routes() -> Binder<Route> {
        return Binder(base) { base, route in
            route.execute(from: base)
        }
    }
}

#endif
