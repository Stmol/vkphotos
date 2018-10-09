//
//  UploadingPhotos.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 16/06/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Photos

struct PhotosDataForUpload {
    let vkAlbum: VKAlbum
    let photoAssets: [PHAsset]
    let photoImages: [UIImage]

    init(_ vkAlbum: VKAlbum, photoAssets: [PHAsset] = [], photoImages: [UIImage] = []) {
        self.vkAlbum = vkAlbum
        self.photoAssets = photoAssets
        self.photoImages = photoImages
    }
}
