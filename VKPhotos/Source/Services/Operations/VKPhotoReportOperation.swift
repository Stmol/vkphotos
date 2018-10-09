//
// Created by Yury Smidovich on 10/09/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation

class VKPhotoReportAndDislikeOperation: VKPhotoAPIOperation<Bool> {

    let reason: VKPhotoReportReason

    init(_ api: VKApiClient, _ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason) {
        self.reason = reason
        super.init(api, vkPhoto)
    }

    override func main() {
        // TODO: Предусмотреть выбор, просто репорт или репорт с дизлайком
        api.photoReportAndDislike(vkPhoto, reason, token: token)
            .then { [weak self] result in
                guard let this = self, !this.isCancelled else {
                    self?.error = APIOperationError.cancelled; return
                }

                this.result = result

                if !result { return }
                DispatchQueue.main.async {
                    dispatch(.vkPhotoReported, VKPhotoReportedEvent(vkPhoto: this.vkPhoto))
                }
            }
            .catch { [weak self] error in self?.error = error }
            .always { [weak self] in self?.state = .isFinished }
    }
}
