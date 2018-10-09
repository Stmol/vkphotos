//
//  InfinityList.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 03/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

protocol InfinityGridDelegate: class {
    func onScrollEndReached()
    func onRefresh()
}

//
//  Такая сетка которая умеет подгружать по достижению конца списка
//  И умеет рефрешить себя
//
class InfinityGrid: UICollectionView {
    weak var scrollDelegate: InfinityGridDelegate?

    var onEndReachedThreshold: CGFloat { return 150 }
    var isScrollEndReached = false
    var isShouldEndScrollReachingFire: ((InfinityGrid) -> Bool)?
    var isRefreshing: Bool { return refreshControl != nil && refreshControl!.isRefreshing }

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        initialization()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialization()
    }

    fileprivate func initialization() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        refreshControl.isUserInteractionEnabled = false
        refreshControl.layer.zPosition = -1
        refreshControl.backgroundColor = .white

        self.refreshControl = refreshControl
    }

    @objc func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard
            // TODO: Подгружать только в случае если скролинг происходит по направлению вниз
            //scrollView.panGestureRecognizer.translation(in: scrollView.superview).y < 0,
            isShouldEndScrollReachingFire != nil && isShouldEndScrollReachingFire!(self),
            scrollView.contentSize.height > scrollView.frame.size.height
            else { return }

        let bottomEdge: CGFloat = scrollView.contentOffset.y + scrollView.frame.size.height
        guard !isScrollEndReached && bottomEdge >= (scrollView.contentSize.height - onEndReachedThreshold) else { return }

        isScrollEndReached = true
        scrollDelegate?.onScrollEndReached()
    }

    @objc private func onRefresh(_ refreshControl: UIRefreshControl) {
        guard let delegate = scrollDelegate else {
            refreshControl.endRefreshing(); return
        }

        delegate.onRefresh()
    }
}
