//
// Created by Yury Smidovich on 28/08/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Hydra

final class VKPhotosMultiMoveOperation: VKPhotosAPIOperation<[VKPhoto]> {
    let targetVKAlbum: VKAlbum
    let fromVKAlbum: VKAlbum

    init(_ api: VKApiClient, _ vkPhotos: [VKPhoto], _ targetVKAlbum: VKAlbum, _ fromVKAlbum: VKAlbum) {
        self.targetVKAlbum = targetVKAlbum
        self.fromVKAlbum = fromVKAlbum

        super.init(api, vkPhotos)
    }

    override func main() {
        var promises = [Promise<[Int]>]()
        vkPhotos.forEach(slice: 25) {
            promises.append(api.photosMultiMove($0, to: targetVKAlbum, token: token))
        }

        if promises.isEmpty {
            error = APIOperationError.failed
            state = .isFinished
            return
        }

        all(promises, concurrency: 1)
            .then { [weak self] responses in
                guard let this = self, !this.isCancelled, responses.count > 0 else {
                    self?.error = APIOperationError.failed; return
                }

                var photosMovedIds = [Int]()
                responses.forEach({ photosMovedIds.append(contentsOf: $0) })

                let movedVKPhotos = this.vkPhotos
                    .map({ vkPhoto -> VKPhoto in
                        var vkPhoto = vkPhoto
                        vkPhoto.albumId = this.targetVKAlbum.id // TODO: А вот точно так надо делать? А не из апи ли получать?
                        return vkPhoto
                     })
                    .filter({ photosMovedIds.contains($0.id) })

                this.result = movedVKPhotos

                guard !movedVKPhotos.isEmpty else { return }
                DispatchQueue.main.async {
                    dispatch(.vkPhotosMoved, VKPhotosMovedEvent(
                        vkPhotos: movedVKPhotos, fromVKAlbum: this.fromVKAlbum, targetVKAlbum: this.targetVKAlbum
                    ))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
