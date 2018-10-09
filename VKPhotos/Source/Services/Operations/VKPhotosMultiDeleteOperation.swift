//
// Created by Yury Smidovich on 08/08/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Hydra

final class VKPhotosMultiDeleteOperation: VKPhotosAPIOperation<[VKPhoto]> {
    override func main() {
        var promises = [Promise<[Int]>]()
        vkPhotos.forEach(slice: 25) { promises.append(api.photosMultiDelete($0, token: token)) }

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

                var deletedIds = [Int]()
                responses.forEach({ deletedIds.append(contentsOf: $0) })

                let deletedVKPhotos = this.vkPhotos.filter({ deletedIds.contains($0.id) })
                this.result = deletedVKPhotos

                if deletedVKPhotos.isEmpty { return }
                DispatchQueue.main.async {
                    dispatch(.vkPhotosDeleted, VKPhotosDeletedEvent(vkPhotos: deletedVKPhotos))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }

        //        forEach Крутая подсказка - оставлю специально. Так можно сделать если нужны паузы между запросами к апи
//                .then { [weak self] ids in
//                    deletedPhotoIDs.append(contentsOf: ids)
//
//                    // Последний ответ
                      // delay - так можно соблюсти паузы между запросами
//                    if let count = self?.vkPhotos.count, deletedCount >= count {
//                        self?.state = .isFinished
//                    }
//                }
    }
}
