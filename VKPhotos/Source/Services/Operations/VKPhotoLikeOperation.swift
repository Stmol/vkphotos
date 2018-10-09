//
// Created by Yury Smidovich on 25/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Hydra

final class VKPhotoLikeOperation: VKPhotoAPIOperation<Int> {
    override func main() {
        api.likePhoto(vkPhoto)
            .then { [weak self] likesCount in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = likesCount

                DispatchQueue.main.async { [weak self] in
                    guard let vkPhoto = self?.vkPhoto else { return }
                    dispatch(.vkPhotoLiked, VKPhotoLikedEvent(vkPhoto: vkPhoto, likesCount: likesCount))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
