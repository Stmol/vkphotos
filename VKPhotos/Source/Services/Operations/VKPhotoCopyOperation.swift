//
//  VKPhotoCopyOperation.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 31/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoCopyOperation: VKPhotoAPIOperation<VKPhoto> {
    override func main() {
        api.copyPhoto(vkPhoto, token: token)
            .then { [weak self] vkPhoto in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = vkPhoto

                DispatchQueue.main.async {
                    dispatch(.vkPhotosCopied, VKPhotoCopiedEvent(vkPhoto: vkPhoto))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
