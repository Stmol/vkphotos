//
// Created by Yury Smidovich on 08/05/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos

protocol PhotosCollectionControllerDelegate: class {
    func photoChecked(asset: PHAsset)
    func photoUnchecked(asset: PHAsset)
    func getSelectedAssets() -> Set<PHAsset>
}

class PhotosCollectionController: UIViewController {
    @IBOutlet weak var photosCollectionView: UICollectionView!

    @IBOutlet weak var uploadButton: UIBarButtonItem!
    @IBOutlet weak var counterBarButtonItem: UIBarButtonItem!

    var localAlbum: LocalAlbum?
    weak var delegate: PhotosCollectionControllerDelegate?

    private var counterBadge: CounterBadge!
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let warningFeedback = UINotificationFeedbackGenerator()
    private var photos = [PHAsset]()

    private var counterText: String {
        return "\(selectedPhotoAssetsCount)/\(LibraryPhotoPickerConst.MAX_PHOTOS_TO_UPLOAD)"
    }
    private var isPhotosLimitReached: Bool {
        return selectedPhotoAssetsCount >= LibraryPhotoPickerConst.MAX_PHOTOS_TO_UPLOAD
    }
    private var selectedPhotoAssetsCount: Int {
        if let selectedAssets = delegate?.getSelectedAssets() {
            return selectedAssets.count
        }

        return 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: Do something with fatal error
        guard let localAlbum = self.localAlbum else { fatalError("Album cannot be empty") }
        navigationItem.title = localAlbum.name

        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self

        selectionFeedback.prepare()
        warningFeedback.prepare()

        if let navigationController = navigationController as? PhotosCollectionControllerDelegate {
            delegate = navigationController
        }

        counterBadge = CounterBadge(with: counterText, isAlertState: isPhotosLimitReached)
        counterBarButtonItem.customView = counterBadge.view

        DispatchQueue.global(qos: .userInteractive).async {
            localAlbum.photosFetchResult.enumerateObjects { asset, _, _ in
                if asset.mediaType == .image {
                    self.photos.append(asset)
                }
            }

            DispatchQueue.main.async {
                self.photosCollectionView.reloadData()

                if self.photos.count > 0 {
                    let indexPath = IndexPath(item: self.photos.count - 1, section: 0)
                    // TODO Не всегда срабатывает
                    self.photosCollectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateUploadButton()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews() // TODO: При повороте экрана скролит в середину списка
        photosCollectionView.collectionViewLayout.invalidateLayout()
    }

    @IBAction func closeButtonTap(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func uploadButtonTap(_ sender: UIBarButtonItem) {
        if let navigationController = navigationController as? PhotoPickerNavigationController {
            // TODO Refactoring
            navigationController.childControllerUploadButtonTap()
        }
    }

    private func updateUploadButton() {
        uploadButton.isEnabled = selectedPhotoAssetsCount > 0
    }
}

extension PhotosCollectionController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! PhotosCollectionCell
        let photoAsset = photos[indexPath.row]

        switch cell.checkbox.checkState {
        case .checked: // UNCHECK
            delegate?.photoUnchecked(asset: photoAsset)

            cell.uncheckPhoto()
            counterBadge.pop(with: counterText, isAlertState: isPhotosLimitReached)
        case .unchecked: // CHECK
            if isPhotosLimitReached {
                counterBadge.shake()
                cell.checkbox.pop()

                warningFeedback.notificationOccurred(.warning)
                warningFeedback.prepare()

                return
            }

            delegate?.photoChecked(asset: photoAsset)

            cell.checkPhoto()
            counterBadge.pop(with: counterText, isAlertState: isPhotosLimitReached)

            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
        default: break
        }

        updateUploadButton()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotosPickerCell", for: indexPath) as! PhotosCollectionCell

        let asset = photos[indexPath.row]
        if let selectedAssets = delegate?.getSelectedAssets(), selectedAssets.contains(asset) {
            cell.checkPhoto()
        }

        let manager = PHImageManager.default()
        if cell.tag != 0 {
            manager.cancelImageRequest(PHImageRequestID(cell.tag))
        }

        //let options = PHImageRequestOptions()
        //options.isNetworkAccessAllowed = false
        //options.deliveryMode = .opportunistic

        cell.tag = Int(manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200.0, height: 200.0),
            contentMode: .aspectFill,
            options: nil) { result, _ in cell.imageView.image = result }
        )

        return cell
    }
}

extension PhotosCollectionController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let itemSize = floor((collectionView.bounds.width - 6) / 3)

        return CGSize(width: itemSize, height: itemSize)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 3
    }
}
