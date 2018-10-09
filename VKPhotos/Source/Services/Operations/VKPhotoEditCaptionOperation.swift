//
// Created by Yury Smidovich on 30/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKPhotoEditCaptionOperation: VKPhotoAPIOperation<Bool> {
    var caption: String

    init(_ api: VKApiClient, _ vkPhoto: VKPhoto, _ caption: String) {
        self.caption = caption
        super.init(api, vkPhoto)
    }

    override func main() {
        api.photosEdit(id: vkPhoto.id, caption: caption, token: token)
            .then { [weak self] isSuccess in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                self?.result = isSuccess

                guard isSuccess else { return }
                DispatchQueue.main.async {
                    // TODO: Не написать ли кастомный апи вызов который вернет caption?
                    dispatch(.vkPhotoCaptionEdited, VKPhotoCaptionEditedEvent(
                        vkPhoto: this.vkPhoto, caption: this.caption
                    ))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished}
    }
}
