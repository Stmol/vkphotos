//
//  AllPhotosListViewController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class AllPhotosListViewController: PhotosGridController {
    @IBOutlet override weak var photosGridCollection: PhotosGridCollection! {
        get { return super.photosGridCollection }
        set { super.photosGridCollection = newValue }
    }

    // TODO: Мы не можем перемещать из вкладки все фото, потому что сложно отследить какое фото в каком альбоме
    //       но сделаю это в будущих обновлениях
    override var isMoveButtonEnabled: Bool { return false }
}

extension AllPhotosListViewController: NavigationBarDelegate {
    var rightBarButton: UIBarButtonItem? { return editBarButton }
}
