//
// Created by Yury Smidovich on 04/08/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Hydra
import Foundation

final class VKAlbumCreateOperation: APIOperation<VKAlbum> {
    let dto: VKAlbumDTO

    init(_ api: VKApiClient, _ dto: VKAlbumDTO) {
        self.dto = dto
        super.init(api)
    }

    override func main() {
        api.createAlbum(dto, token: token)
            .then { [weak self] vkAlbum in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = vkAlbum

                DispatchQueue.main.async {
                    dispatch(.vkAlbumCreated, VKAlbumCreatedEvent(vkAlbum: vkAlbum))
                }
            }
            .catch { [weak self] error in
                dump(error)
                self?.error = error
            }
            .always { [weak self] in self?.state = .isFinished }
    }
}
