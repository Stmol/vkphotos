//
// Created by Yury Smidovich on 25/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Hydra

enum APIOperationError: Error {
    case cancelled, failed
}

class APIOperation<ResultType>: AsyncOperation {
    let api: VKApiClient
    let token: InvalidationToken
    var result: ResultType?
    var error: Error?

    init(_ api: VKApiClient) {
        self.api = api
        self.token = InvalidationToken()
    }

    override func cancel() {
        super.cancel()
        token.invalidate()
    }
}

class VKPhotoAPIOperation<ResultType>: APIOperation<ResultType> {
    let vkPhoto: VKPhoto

    init(_ api: VKApiClient, _ vkPhoto: VKPhoto) {
        self.vkPhoto = vkPhoto
        super.init(api)
    }
}

class VKPhotosAPIOperation<ResultType>: APIOperation<ResultType> {
    let vkPhotos: [VKPhoto]

    init(_ api: VKApiClient, _ vkPhotos: [VKPhoto]) {
        self.vkPhotos = vkPhotos
        super.init(api)
    }
}
