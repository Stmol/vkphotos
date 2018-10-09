//
// Created by Yury Smidovich on 29/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotosUpdateInfoOperation: VKPhotosAPIOperation<[VKPhotoInfo]> {
    override func main() {
        api.getPhotosInfo(vkPhotos)
            .then { [weak self] photosInfo in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = photosInfo

                DispatchQueue.main.async {
                    dispatch(.vkPhotosInfoUpdated, VKPhotosInfoUpdatedEvent(vkPhotos: this.vkPhotos, vkPhotosInfo: photosInfo))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
