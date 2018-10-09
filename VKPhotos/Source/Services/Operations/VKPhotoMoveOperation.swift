//
//  VKPhotoMoveOperation.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 31/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoMoveOperation: VKPhotoAPIOperation<VKPhoto> {
    let targetVKAlbum: VKAlbum

    init(_ api: VKApiClient, _ vkPhoto: VKPhoto, _ targetVKAlbum: VKAlbum) {
        self.targetVKAlbum = targetVKAlbum
        super.init(api, vkPhoto)
    }

    override func main() {
        api.movePhoto(vkPhoto, to: targetVKAlbum, token: token)
            .then { [weak self] vkPhoto in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = vkPhoto

                DispatchQueue.main.async {
                    dispatch(.vkPhotoMoved, VKPhotoMovedEvent(
                        // TODO: this.vkPhoto.albumId заменить на VKAlbum сущность
                        vkPhoto: vkPhoto, fromVKAlbumID: this.vkPhoto.albumId, targetVKAlbum: this.targetVKAlbum
                    ))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
