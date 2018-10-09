//
// Created by Yury Smidovich on 25/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Foundation
import Hydra

final class VKPhotosSyncOperation: AsyncOperation {
    var result: (vkPhotos: [VKPhoto], totalCount: Int)?
    var error: Error?

    private let api: VKApiClient

    private(set) var photosCount: Int
    private(set) var countInBatch: Int

    private(set) var fetchMethod: ((Int, Int) -> Promise<VKPhotosResult>)

    init(_ apiClient: VKApiClient, _ photosCount: Int, _ countInBatch: Int = 200, _ fetchMethod: @escaping (Int, Int) -> Promise<VKPhotosResult>) {
        self.api = apiClient
        self.photosCount = photosCount
        self.countInBatch = countInBatch
        self.fetchMethod = fetchMethod
    }

    override func main() {
        let requestsCount = photosCount <= countInBatch ? 1 : Int((Float(photosCount) / Float(countInBatch)).rounded(.up))
        if photosCount <= 0 || requestsCount <= 0 {
            state = .isFinished; return
        }

        let requests = (0 ..< requestsCount).map({ index -> Promise<VKPhotosResult> in
            let offset = index * countInBatch
            let count = (photosCount - offset) < countInBatch ? photosCount - offset : countInBatch

            return fetchMethod(count, offset)
        })

        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }

        print("♻️ Start sync photos by \(requests.count) request(s)")
        all(requests, concurrency: 3)
            .then { [weak self] responses in
                guard let this = self, !this.isCancelled, responses.count > 0 else {
                    self?.error = APIOperationError.failed; return
                }

                var vkPhotos = [VKPhoto]()
                responses.forEach { vkPhotos.append(contentsOf: $0.vkPhotos) }

                this.result = (vkPhotos, responses.last!.totalCount)
            }
            .catch { [weak self] error in
                self?.error = error
            }
            .always(in: .main) { [weak self] in
                print("♻️ End sync photos")
                self?.state = .isFinished
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
    }
}
