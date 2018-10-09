//
// Created by Yury Smidovich on 06/08/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoMakeCoverOperation: VKPhotoAPIOperation<Bool> {
    override func main() {
        api.photosMakeCover(vkPhoto, token: token)
            .then { [weak self] result in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = result
                guard result else { return }

                DispatchQueue.main.async {
                    dispatch(.vkPhotoMakeCover, VKPhotoMakeCoverEvent(vkPhoto: this.vkPhoto))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
