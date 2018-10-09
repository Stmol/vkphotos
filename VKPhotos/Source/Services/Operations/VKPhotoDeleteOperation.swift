//
//  VKPhotoDeleteOperation.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 29/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoDeleteOperation: VKPhotoAPIOperation<Bool> {
    override func main() {
        api.photosDelete(id: vkPhoto.id, token: token)
            .then { [weak self] isSuccess in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = isSuccess

                if !isSuccess { return }
                DispatchQueue.main.async {
                    dispatch(.vkPhotosDeleted, VKPhotosDeletedEvent(vkPhotos: [this.vkPhoto]))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
