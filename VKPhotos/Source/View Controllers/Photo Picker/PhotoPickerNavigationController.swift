//
//  PhotoPickerNavigationController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 05/06/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos

protocol PhotoPickerDelegate: class {
    func photosSelectingFinished(assets: Set<PHAsset>)
}

struct LibraryPhotoPickerConst {
    static let MAX_PHOTOS_TO_UPLOAD = 20
}

class PhotoPickerNavigationController: UINavigationController {
    weak var photoPickerDelegate: PhotoPickerDelegate?
    var selectedPhotoAssets = Set<PHAsset>()

    func childControllerUploadButtonTap() {
        if selectedPhotoAssets.isEmpty { return }

        dismiss(animated: true) { [weak self] in
            guard let selectedPhotoAssets = self?.selectedPhotoAssets else { return }
            self?.photoPickerDelegate?.photosSelectingFinished(assets: selectedPhotoAssets)
        }
    }
}

extension PhotoPickerNavigationController: PhotosCollectionControllerDelegate {
    func getSelectedAssets() -> Set<PHAsset> {
        return selectedPhotoAssets
    }

    func photoChecked(asset: PHAsset) {
        selectedPhotoAssets.insert(asset)
    }

    func photoUnchecked(asset: PHAsset) {
        selectedPhotoAssets.remove(asset)
    }
}
