//
// Created by Yury Smidovich on 03/08/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKAlbumDeleteOperation: APIOperation<Bool> {
    let vkAlbum: VKAlbum

    init(_ api: VKApiClient, _ vkAlbum: VKAlbum) {
        self.vkAlbum = vkAlbum
        super.init(api)
    }

    override func main() {
        api.photosDeleteAlbum(vkAlbum, token: token)
            .then { [weak self] result in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = result

                if !result { return }
                DispatchQueue.main.async {
                    dispatch(.vkAlbumsDeleted, VKAlbumsDeletedEvent(vkAlbums: [this.vkAlbum]))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
