//
//  PhotosUploadController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 11/06/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos
import Firebase

protocol PhotosUploadControllerDelegate: class {
    func onPhotoCaptionEdit(_ vkPhoto: VKPhoto, caption: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
}

class PhotosUploadController: UITableViewController {
    deinit {
        uploadOperationQueue.cancelAllOperations()
        api.token.invalidate()
    }

    let photoUploadingCellID = "photoUploadingCell"
    let seguePhotoDetails = "showPhotoDetails"

    var photosDataForUpload: PhotosDataForUpload!
    weak var delegate: PhotosUploadControllerDelegate?

    private let api = VKApiClient()
    private var uploadPhotoTasks: [UploadPhotoTask] = []
    private var vkPhotoUploadInfo: VKPhotoUploadInfo?

    private lazy var uploadOperationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Upload Queue"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated

        return queue
    }()

    @IBAction func doneButtonTap(_ sender: UIBarButtonItem) {
        if uploadOperationQueue.operationCount == 0 {
            dismiss(animated: true) { StoreReviewHelper.checkAndAskForReview() }
            return
        }

        let stopActionSheet = UIAlertController(
            title: "Uploading in progress".localized(),
            message: nil,
            preferredStyle: .actionSheet)

        let stopAction = UIAlertAction(title: "Stop uploading".localized(), style: .destructive) { [weak self] _ in
            Analytics.logEvent(AnalyticsEvent.PhotoUploadInterrupt, parameters: nil)
            self?.uploadOperationQueue.cancelAllOperations()
            self?.dismiss(animated: true)
        }

        stopActionSheet.addAction(stopAction)
        stopActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))

        present(stopActionSheet, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()

        if photosDataForUpload.photoAssets.isEmpty && photosDataForUpload.photoImages.isEmpty {
            dismiss(animated: false); return
        }

        buildTasksToUpload()
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard vkPhotoUploadInfo == nil else { return }
        api.getUploadServer(albumId: photosDataForUpload.vkAlbum.id)
            .then { [weak self] info in
                self?.vkPhotoUploadInfo = info
                self?.startUploading()
            }
            .catch { [weak self] _ in
                self?.showErrorNotification("Something went wrong".localized())
            }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard
            segue.identifier == seguePhotoDetails,
            let controller = segue.destination as? PhotosUploadEditDetailsController,
            let uploadingTask = sender as? UploadPhotoTask,
            let vkPhoto = uploadingTask.uploadedVkPhoto
            else { return }

        controller.delegate = self
        controller.vkPhoto = vkPhoto
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return photosDataForUpload.vkAlbum.title
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploadPhotoTasks.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: photoUploadingCellID, for: indexPath) as! PhotosUploadTableCell

        cell.delegate = self

        let uploadingTask = uploadPhotoTasks[indexPath.row]

        // TODO cancelImageRequest
        uploadingTask.getPreviewImage { image in
            // TODO Оптимизировать (кешировать)
            guard let image = image else { return }
            DispatchQueue.main.async {
                cell.photoPreview.image = image
            }
        }

        cell.updateUIByTask(uploadingTask)

        return cell
    }

    private func buildTasksToUpload() {
        for asset in photosDataForUpload.photoAssets {
            let task = UploadAssetTask(asset)
            task.delegate = self
            uploadPhotoTasks.append(task)
        }

        for image in photosDataForUpload.photoImages {
            let task = UploadImageTask(image)
            task.delegate = self
            uploadPhotoTasks.append(task)
        }
    }

    private func startUploading() {
        guard let uploadInfo = vkPhotoUploadInfo else { return }

        for uploadingTask in uploadPhotoTasks {
            guard uploadingTask.status != .inProgress else { continue }

            uploadOperationQueue.addOperation(
                createOperation(for: uploadingTask, uploadInfo.albumId, uploadInfo.uploadUrl)
            )
        }

        Analytics.logEvent(AnalyticsEvent.PhotoUploadStart, parameters: ["upload_count": uploadOperationQueue.operationCount])
    }

    private func createOperation(for uploadingTask: UploadPhotoTask, _ albumId: Int, _ url: String) -> PhotoUploader {
        let operation = PhotoUploader(uploadingTask, url)
        operation.completionBlock = { [weak self] in
            guard let this = self, let uploadResult = operation.uploadPhotoTask.vkPhotoUploadResult else {
                operation.uploadPhotoTask.status = .error
                return
            }

            this.api.savePhoto(uploadResult)
                .then { vkPhoto in
                    guard vkPhoto.id > 0 else { operation.uploadPhotoTask.status = .error; return }
                    operation.uploadPhotoTask.status = .done
                    operation.uploadPhotoTask.uploadedVkPhoto = vkPhoto

                    // TODO: Не очень хорошо здесь бросать ивент, надо либо перенести в операцию либо...?
                    dispatch(.vkPhotosUploaded, VKPhotosUploadedEvent(
                        vkPhotos: [vkPhoto],
                        targetVKAlbum: this.photosDataForUpload.vkAlbum
                    ))
                }
                .catch { _ in operation.uploadPhotoTask.status = .error }
        }

        return operation
    }
}

extension PhotosUploadController: PhotosUploadingCellDelegate {
    func addCaptionButtonTapped(_ cell: PhotosUploadTableCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            indexPath.row <= uploadPhotoTasks.count
            else { return }

        let uploadingTask = uploadPhotoTasks[indexPath.row]
        if uploadingTask.status != .done { return }

        performSegue(withIdentifier: seguePhotoDetails, sender: uploadingTask)
    }

    func retryButtonTapped(_ cell: PhotosUploadTableCell) {
        guard
            let uploadInfo = vkPhotoUploadInfo,
            let indexPath = tableView.indexPath(for: cell),
            indexPath.row <= uploadPhotoTasks.count
            else { return }

        let uploadingTask = uploadPhotoTasks[indexPath.row]
        guard uploadingTask.status == .error && uploadingTask.uploadedVkPhoto == nil else {
            uploadingTask.status = .done; return
        }

        uploadingTask.status = .ready

        uploadOperationQueue.addOperation(
            createOperation(for: uploadingTask, uploadInfo.albumId, uploadInfo.uploadUrl)
        )
    }
}

extension PhotosUploadController: UploadPhotoTaskDelegate {
    func statusDidUpdate(_ task: UploadPhotoTask, _ status: UploadPhotoTaskStatus) {
        guard let index = uploadPhotoTasks.index(where: { $0 === task }) else { return }

        DispatchQueue.main.async {
            if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PhotosUploadTableCell {
                cell.updateStatus(status)
            }
        }
    }

    func progressDidUpdate(_ task: UploadPhotoTask, _ progress: Float) {
        guard let index = uploadPhotoTasks.index(where: { $0 === task }) else { return }

        DispatchQueue.main.async {
            if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? PhotosUploadTableCell {
                cell.updateProgressBar(progress, animated: progress != 0)
            }
        }
    }
}

extension PhotosUploadController: PhotoCaptionEditingProtocol {
    func onCaptionSave(_ vkPhoto: VKPhoto, caption: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        guard
            let index = uploadPhotoTasks.index(where: { $0.uploadedVkPhoto != nil && $0.uploadedVkPhoto! == vkPhoto })
            else { return nil }

        Analytics.logEvent(AnalyticsEvent.PhotoEditCaption, parameters: ["source": "upload"])

        return delegate?.onPhotoCaptionEdit(vkPhoto, caption: caption) { [weak self] result in
            if result.isSuccess && self?.uploadPhotoTasks[index].uploadedVkPhoto != nil {
                self?.uploadPhotoTasks[index].uploadedVkPhoto!.text = caption
            }

            completion?(result)
        }
    }
}
