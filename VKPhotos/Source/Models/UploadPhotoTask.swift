//
//  UploadPhotoTask.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 10/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos
import Firebase

enum UploadPhotoTaskStatus {
    case ready, done, error, inProgress
}

protocol UploadPhotoTaskDelegate: class {
    func statusDidUpdate(_ task: UploadPhotoTask, _ status: UploadPhotoTaskStatus)
    func progressDidUpdate(_ task: UploadPhotoTask, _ progress: Float)
}

protocol UploadPhotoTask: class {
    var status: UploadPhotoTaskStatus { get set }
    var progress: Float { get set }

    var vkPhotoUploadResult: VKPhotoUploadResult? { get set }
    var uploadedVkPhoto: VKPhoto? { get set }
    var delegate: UploadPhotoTaskDelegate? { get set }

    func getPreviewImage(_ completion: @escaping (UIImage?) -> Void)
    func getPhotoDataForUpload(_ completion: @escaping (Data?) -> Void)
}

class UploadAssetTask: UploadPhotoTask {
    var vkPhotoUploadResult: VKPhotoUploadResult?
    var uploadedVkPhoto: VKPhoto?

    weak var delegate: UploadPhotoTaskDelegate?

    var status: UploadPhotoTaskStatus = .ready {
        didSet {
            delegate?.statusDidUpdate(self, status)

            switch status {
            case .error, .ready, .inProgress: self.progress = 0
            case .done: self.progress = 1
            }

            if status == .error {
                Analytics.logEvent(AnalyticsEvent.PhotoUploadError, parameters: nil)
            }
        }
    }
    var progress: Float = 0 {
        didSet {
            if progress != oldValue {
                delegate?.progressDidUpdate(self, progress)
            }
        }
    }

    private let asset: PHAsset
    private let imageManager = PHImageManager()
    private let imageQueue = DispatchQueue(label: "uploadPhoto.asset.retrieve", attributes: .concurrent)

    init(_ asset: PHAsset) {
        self.asset = asset
    }

    func getPreviewImage(_ completion: @escaping (UIImage?) -> Void) {
        imageQueue.async {
            self.imageManager.requestImage(
                for: self.asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: nil) { image, _ in completion(image) }
        }
    }

    func getPhotoDataForUpload(_ completion: @escaping (Data?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = true

        self.imageManager.requestImageData(for: self.asset, options: options) { data, _, _, _ in
            completion(data)
        }
    }
}

class UploadImageTask: UploadPhotoTask {
    var vkPhotoUploadResult: VKPhotoUploadResult?
    var uploadedVkPhoto: VKPhoto?

    weak var delegate: UploadPhotoTaskDelegate?

    var status: UploadPhotoTaskStatus = .ready {
        didSet {
            delegate?.statusDidUpdate(self, status)

            switch status {
            case .error, .ready, .inProgress: self.progress = 0
            case .done: self.progress = 1
            }
        }
    }
    var progress: Float = 0 {
        didSet {
            if progress != oldValue {
                delegate?.progressDidUpdate(self, progress)
            }
        }
    }

    private let image: UIImage
    private let imageQueue = DispatchQueue(label: "uploadPhoto.image.transform", attributes: .concurrent)

    init(_ image: UIImage) {
        self.image = image
    }

    func getPreviewImage(_ completion: @escaping (UIImage?) -> Void) {
        imageQueue.async { [weak self] in
            completion(self?.image.scaled(toWidth: 200))
        }
    }

    func getPhotoDataForUpload(_ completion: @escaping (Data?) -> Void) {
        imageQueue.async { // TODO Check weak self
            autoreleasepool {
                if let data = UIImageJPEGRepresentation(self.image, 0.9) { completion(data) }
            }
        }
    }
}
