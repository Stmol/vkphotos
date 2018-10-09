//
//  PhotoUploader.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 10/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Alamofire
import Crashlytics

class PhotoUploader: Operation {
    let uploadPhotoTask: UploadPhotoTask
    let uploadServerUrl: String
    private var uploadRequest: Alamofire.UploadRequest?

    init(_ uploadPhotoTask: UploadPhotoTask, _ uploadServerUrl: String) {
        self.uploadPhotoTask = uploadPhotoTask
        self.uploadServerUrl = uploadServerUrl
    }

    override func cancel() {
        super.cancel()
        uploadRequest?.cancel()
    }

    override func main() {
        if isCancelled { return }

        let group = DispatchGroup()
        group.enter()

        uploadPhotoTask.status = .inProgress

        uploadPhotoTask.getPhotoDataForUpload { [weak self] data in
            guard let this = self, let imageData = data else {
                self?.uploadPhotoTask.status = .error
                group.leave(); return
            }

            Alamofire.upload(
                multipartFormData: { $0.append(imageData, withName: "file1", fileName: "file1.jpeg", mimeType: "image/jpeg") },
                to: this.uploadServerUrl,
                encodingCompletion: { result in
                    switch result {

                    case .failure(let error):
                        Crashlytics.sharedInstance().recordError(error)
                        this.uploadPhotoTask.status = .error
                        group.leave()

                    case .success(let upload, _, _):
                        guard this.isCancelled == false else {
                            upload.cancel(); group.leave(); return
                        }

                        this.uploadRequest = upload

                        upload
                            .uploadProgress { this.uploadPhotoTask.progress = Float($0.fractionCompleted) }
                            .responseString { response in
                                do {
                                    defer { group.leave() }

                                    guard
                                        let value = response.value,
                                        let data = value.data(using: .utf8)
                                        else {
                                            this.uploadPhotoTask.status = .error; return
                                        }

                                    this.uploadPhotoTask.vkPhotoUploadResult = try JSONDecoder().decode(VKPhotoUploadResult.self, from: data)
                                } catch {
                                    Crashlytics.sharedInstance().recordError(error)
                                    this.uploadPhotoTask.status = .error
                                    group.leave()
                                }
                        }
                    }
                }
            )
        }

        group.wait()
    }
}
