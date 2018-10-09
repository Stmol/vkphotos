//
// Created by Yury Smidovich on 29/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoRestoreOperation: VKPhotoAPIOperation<Bool> {
    override func main() {
        api.photosRestore(id: vkPhoto.id, token: token)
            .then { [weak self] isSuccess in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = isSuccess
                guard isSuccess else { return }

                DispatchQueue.main.async {
                    dispatch(.vkPhotosRestored, VKPhotosRestoredEvent(vkPhotos: [this.vkPhoto]))
                }
            }
            .catch { [weak self] error in self?.error = error}
            .always { [weak self] in self?.state = .isFinished }
    }
}
