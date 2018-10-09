//
//  AlbumPhotosViewController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 11/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos
import Firebase

protocol AlbumPhotosDelegate: class {
    func photosInAlbumDidChanged()
}

class AlbumPhotosViewController: PhotosGridController {
    let localPhotosSegueID = "showLocalPhotosSegue"
    let uploadProgressSegueID = "showPhotoUploadProgressSegue"

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var isMoveButtonEnabled: Bool {
        // Нельзя перемещать фотки из альбома "Фото с моей страницы"
        if let vkAlbum = vkAlbum, vkAlbum.id == -6 { return false }
        return super.isMoveButtonEnabled
    }

    @IBOutlet override weak var photosGridCollection: PhotosGridCollection! {
        get { return super.photosGridCollection }
        set { super.photosGridCollection = newValue }
    }

    var vkAlbum: VKAlbum?
    weak var albumPhotosDelegate: AlbumPhotosDelegate?

    lazy var uploadPhotosBarButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(uploadPhotosBarButtonTapped))
    }()

    var defaultRightBarButtons: [UIBarButtonItem] {
        var barButtons = [editBarButton]

        if (vkAlbum?.isSystem) == false {
            barButtons.append(uploadPhotosBarButton)
        }

        return barButtons
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let vkAlbum = vkAlbum else {
            // TODO Возвращать на экран списка альбомов
            showWarningNotification(with: "Album does't select".localized())
            return
        }

        // TODO: Переименовать `parentController`
        parentController = self

        navigationItem.title = vkAlbum.title
        navigationItem.rightBarButtonItems = defaultRightBarButtons
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParentViewController { // TODO Это выглядит как хак, хотя решает задачу
            // А задача тут в том, чтобы убирать эдит мод при выходе из контроллера
            // но не убирать при появлении галереи
            changeEditMode(to: false)
        }
    }

    override func createPhotoManager() -> (PhotoManager & VKAPIManager) {
        if let vkAlbum = vkAlbum {
            let providerKey = "album.\(vkAlbum.id)"
            return VKPhotoInAlbumManager(key: providerKey, vkAlbum: vkAlbum)
        }

        return super.createPhotoManager()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueId = segue.identifier else { return }

        switch segueId {
        case localPhotosSegueID:
            if let destinationController = segue.destination as? PhotoPickerNavigationController {
                destinationController.photoPickerDelegate = self
            }

        case uploadProgressSegueID:
            if
                let navigationController = segue.destination as? UINavigationController,
                let destinationController = navigationController.topViewController as? PhotosUploadController,
                let data = sender as? PhotosDataForUpload
            {
                destinationController.photosDataForUpload = data
                destinationController.delegate = self
            }

        default:
            break
        }
    }

    override func multipleMove() {
        guard !selectedVKPhotos.isEmpty, let vkAlbum = vkAlbum else {
            HUD.flash(.error, delay: 1.3); return
        }

        if let controller = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "VKAlbumsTable") as? VKAlbumsTableController {

            controller.isSystemAlbumsExcluded = true
            controller.excludedVKAlbumIds = [vkAlbum.id]
            controller.onVKAlbumSelected = { [weak self] targetVKAlbum in
                guard
                    let this = self, let fromVKAlbum = self?.vkAlbum
                    else { HUD.flash(.error, delay: 1.3); return }

                var isShowingHUD = true

                let operation = this.photoManager.multiMove(Array(this.selectedVKPhotos), targetVKAlbum, fromVKAlbum) { [weak self] result in
                    isShowingHUD = false

                    switch result {
                    case .success:
                        self?.changeEditMode(to: false)
                        HUD.hide(animated: true)
                        StoreReviewHelper.checkAndAskForReview()
                    case .failure(let error):
                        guard error != .cancelled else { return }
                        HUD.flash(.error, delay: 1.3)
                    }
                }

                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    guard isShowingHUD, let operation = operation else { return }
                    HUD.show(cancelHandler: { operation.cancel() })
                }

                Analytics.logEvent(AnalyticsEvent.PhotoMultiMove, parameters: ["count": this.selectedVKPhotos.count])
            }

            present(controller, animated: true)
        }
    }

    @objc func uploadPhotosBarButtonTapped(_ sender: UIBarButtonItem) {
        guard let vkAlbum = vkAlbum, vkAlbum.id > 0 else { return }

        let cameraSourceAction = UIAlertAction(title: "Camera".localized(), style: .default) { [weak self] _ in
            self?.askCameraAccess { [weak self] isGranted in
                guard isGranted else { return }

                let imagePicker = UIImagePickerController()
                imagePicker.sourceType = .camera
                imagePicker.delegate = self

                Analytics.logEvent(AnalyticsEvent.PhotoUploadFromCamera, parameters: nil)
                self?.present(imagePicker, animated: true)
            }
        }

        let librarySourceAction = UIAlertAction(title: "Photo Library".localized(), style: .default) { [weak self] _ in
            self?.askPhotosAccess { [weak self] isGranted in
                guard isGranted else { return }

                if let segueId = self?.localPhotosSegueID {
                    Analytics.logEvent(AnalyticsEvent.PhotoUploadFromLib, parameters: nil)
                    self?.performSegue(withIdentifier: segueId, sender: nil)
                }
            }
        }

        let photoSourceActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        photoSourceActionSheet.addAction(cameraSourceAction)
        photoSourceActionSheet.addAction(librarySourceAction)
        photoSourceActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))

        present(photoSourceActionSheet, animated: true)
    }

    fileprivate func askCameraAccess(_ completion: @escaping ((Bool) -> Void)) {
        // TODO!!! Сообщать что нужен доступ к камере!
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        // The user has previously granted access to the camera
        case .authorized: completion(true)
        // The user has not yet been asked for camera access.
        case .notDetermined: AVCaptureDevice.requestAccess(for: .video) { completion($0) }
        // The user can't grant access due to restrictions.
        // The user has previously denied access
        case .denied, .restricted: completion(false)
        }
    }

    fileprivate func askPhotosAccess(_ completion: @escaping ((Bool) -> Void)) {
        // TODO!!! Сообщать что нужен доступ к галерее!
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined: PHPhotoLibrary.requestAuthorization { completion($0 == .authorized) }
        case .authorized: completion(true)
        case .restricted, .denied: completion(false)
        }
    }
}

extension AlbumPhotosViewController: PhotosUploadControllerDelegate {
    func onPhotoCaptionEdit(_ vkPhoto: VKPhoto, caption: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.editPhotoCaption(vkPhoto, caption: caption) { result in
            switch result {
            case .success(let isEdited): completion?((isEdited, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }
}

extension AlbumPhotosViewController: PhotoPickerDelegate {
    func photosSelectingFinished(assets: Set<PHAsset>) {
        guard let vkAlbum = vkAlbum, vkAlbum.id > 0 else { return }
        let data = PhotosDataForUpload(vkAlbum, photoAssets: Array(assets))

        performSegue(withIdentifier: uploadProgressSegueID, sender: data)
    }
}

extension AlbumPhotosViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        picker.dismiss(animated: true)

        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage, let vkAlbum = vkAlbum {
            let data = PhotosDataForUpload(vkAlbum, photoImages: [pickedImage])

            performSegue(withIdentifier: uploadProgressSegueID, sender: data)
        }
    }
}

extension AlbumPhotosViewController: PhotosGridControllerDelegate {
    func changeNavigationUI(tabBar tabBarView: UIView, navigationTitle navigationTitleView: UIView) {
        navigationItem.titleView = navigationTitleView
        navigationItem.rightBarButtonItems = [editBarButton]

        guard let tabBarController = tabBarController else { return }

        tabBarController.view.addSubview(tabBarView)
        tabBarController.view.addConstraints(withFormat: "H:|[v0]|", views: tabBarView)
        tabBarController.view.addConstraints(withFormat: "V:[v0]|", views: tabBarView)
        tabBarView.heightAnchor.constraint(equalTo: tabBarController.tabBar.heightAnchor).isActive = true
    }

    func resetNavigationUI() {
        navigationItem.titleView = nil
        navigationItem.title = vkAlbum!.title
        navigationItem.rightBarButtonItems = defaultRightBarButtons
    }
}
