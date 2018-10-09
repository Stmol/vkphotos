//
//  PhotosListViewController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 12/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

protocol NavigationBarDelegate: class {
    var rightBarButton: UIBarButtonItem? { get }
}

class PhotosListViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    lazy var photosListSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: [
            "All".localized(),
            "Likes".localized()
        ])

        let font = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.medium)
        segmentedControl.setTitleTextAttributes(
            [NSAttributedStringKey.font: font], for: .normal
        )
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.tintColor = .white

        segmentedControl.setWidth(80, forSegmentAt: 0)
        segmentedControl.setWidth(80, forSegmentAt: 1)

        segmentedControl.layer.cornerRadius = segmentedControl.bounds.height / 2.0
        segmentedControl.layer.borderWidth = 1.0
        segmentedControl.layer.masksToBounds = true
        segmentedControl.layer.borderColor = segmentedControl.tintColor.cgColor

        segmentedControl.addTarget(self, action: #selector(changePhotosList), for: .valueChanged)

        return segmentedControl
    }()

    lazy var allPhotosListViewController: AllPhotosListViewController = {
        return storyboard?.instantiateViewController(withIdentifier: "AllPhotosList") as! AllPhotosListViewController
    }()

    lazy var favPhotosListViewController: FavPhotosListViewController = {
        return storyboard?.instantiateViewController(withIdentifier: "FavPhotosList") as! FavPhotosListViewController
    }()

    @objc func changePhotosList(_ sender: UISegmentedControl) {
        updateChildView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChildViewController(toViewController: allPhotosListViewController)

        navigationItem.titleView = photosListSegmentedControl
        navigationItem.rightBarButtonItem = allPhotosListViewController.rightBarButton
    }

    private func addChildViewController(toViewController: PhotosGridController) {
        addChildViewController(toViewController)
        view.addSubview(toViewController.view)

        toViewController.view.frame = view.bounds
        toViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        toViewController.didMove(toParentViewController: self)
        toViewController.parentController = self
    }

    private func removeChildViewController(viewController: PhotosGridController) {
        viewController.willMove(toParentViewController: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
        viewController.parentController = nil
    }

    private func updateChildView() {
        if photosListSegmentedControl.selectedSegmentIndex == 0 {
            removeChildViewController(viewController: favPhotosListViewController)
            addChildViewController(toViewController: allPhotosListViewController)
        } else {
            removeChildViewController(viewController: allPhotosListViewController)
            addChildViewController(toViewController: favPhotosListViewController)
        }

        if let childController = childViewControllers[0] as? NavigationBarDelegate {
            navigationItem.rightBarButtonItem = childController.rightBarButton
        }

//        allPhotosListViewController.view.isHidden = !(photosListSwitcher.selectedSegmentIndex == 0)
//        favPhotosListViewController.view.isHidden = photosListSwitcher.selectedSegmentIndex == 0
    }
}

extension PhotosListViewController: PhotosGridControllerDelegate {
    func changeNavigationUI(tabBar tabBarView: UIView, navigationTitle navigationTitleView: UIView) {
        navigationItem.titleView = navigationTitleView

        guard let tabBarController = tabBarController else { return }

        tabBarController.view.addSubview(tabBarView)
        tabBarController.view.addConstraints(withFormat: "H:|[v0]|", views: tabBarView)
        tabBarController.view.addConstraints(withFormat: "V:[v0]|", views: tabBarView)
        tabBarView.heightAnchor.constraint(equalTo: tabBarController.tabBar.heightAnchor).isActive = true
    }

    func resetNavigationUI() {
        navigationItem.titleView = photosListSegmentedControl
        // TODO: Удалять кастомный таббар надо отсюда
    }
}
