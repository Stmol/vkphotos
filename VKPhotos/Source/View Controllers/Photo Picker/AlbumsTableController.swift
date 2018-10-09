//
//  AlbumsTableController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 15/05/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos

struct LocalAlbum {
    let identifier: String
    let subtype: PHAssetCollectionSubtype

    let name: String
    let photosCount: Int

    let thumbAsset: PHAsset?
    let photosFetchResult: PHFetchResult<PHAsset>
}

class AlbumsTableController: UIViewController {
    let photosControllerSegueID = "showPhotosInLocalAlbum"
    let photosControllerSegueNoAnimationID = "showPhotosInLocalAlbumNoAnimation"
    let localAlbumCellID = "LocalAlbumCell"

    @IBOutlet weak var counterBarButton: UIBarButtonItem!
    @IBOutlet weak var uploadButton: UIBarButtonItem!
    @IBOutlet weak var albumsTable: UITableView! {
        didSet {
            albumsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            albumsTable.tableFooterView = UIView()
        }
    }

    private var counterBadge: CounterBadge!
    private var localAlbums = [LocalAlbum]()
    private var selectedLocalAlbum: LocalAlbum?

    private var counterText: String {
        return "\(selectedPhotoAssetsCount)/\(LibraryPhotoPickerConst.MAX_PHOTOS_TO_UPLOAD)"
    }
    private var isPhotosLimitReached: Bool {
        return selectedPhotoAssetsCount >= LibraryPhotoPickerConst.MAX_PHOTOS_TO_UPLOAD
    }
    private var selectedPhotoAssetsCount: Int {
        if let navigationController = navigationController as? PhotoPickerNavigationController {
            return navigationController.selectedPhotoAssets.count
        }

        return 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        albumsTable.delegate = self
        albumsTable.dataSource = self

        counterBadge = CounterBadge(with: counterText, isAlertState: isPhotosLimitReached)
        counterBarButton.customView = counterBadge.view

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: options)

        smartAlbums.enumerateObjects { collection, _, _ in
            let photosSubtypeAllowed: [PHAssetCollectionSubtype] = [
                .smartAlbumUserLibrary,
                .smartAlbumFavorites,
                .smartAlbumSelfPortraits,
                .smartAlbumPanoramas,
                .smartAlbumScreenshots,
                .smartAlbumAllHidden
                //smartAlbumBursts, .smartAlbumDepthEffect,.smartAlbumLivePhotos,
            ]

            if photosSubtypeAllowed.contains(collection.assetCollectionSubtype) {
                let options = PHFetchOptions()
                //options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

                let photos = PHAsset.fetchAssets(in: collection, options: options)

                if photos.count > 0 {
                    let localAlbum = LocalAlbum(
                        identifier: collection.localIdentifier,
                        subtype: collection.assetCollectionSubtype,

                        name: collection.localizedTitle!,
                        photosCount: photos.count,
                        thumbAsset: photos.lastObject,
                        photosFetchResult: photos
                    )

                    self.localAlbums.append(localAlbum)
                }
            }
        }

        localAlbums.sort(by: { $0.name < $1.name })

        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        albums.enumerateObjects { collection, _, _ in
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

            let photos = PHAsset.fetchAssets(in: collection, options: options)

            if photos.count > 0 {
                let localAlbum = LocalAlbum(
                    identifier: collection.localIdentifier,
                    subtype: collection.assetCollectionSubtype,

                    name: collection.localizedTitle!,
                    photosCount: photos.count,
                    thumbAsset: photos.lastObject,
                    photosFetchResult: photos
                )

                self.localAlbums.append(localAlbum)
            }
        }

        albumsTable.reloadData()

        if let cameraRollAlbum = localAlbums.first(where: { $0.subtype == .smartAlbumUserLibrary }) {
            selectedLocalAlbum = cameraRollAlbum
            performSegue(withIdentifier: photosControllerSegueNoAnimationID, sender: self)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        uploadButton.isEnabled = selectedPhotoAssetsCount > 0
        counterBadge.pop(with: counterText, isAlertState: isPhotosLimitReached)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let selectedRow = albumsTable.indexPathForSelectedRow {
            albumsTable.deselectRow(at: selectedRow, animated: true)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let localAlbum = selectedLocalAlbum else { return }

        let photosCollectionController = segue.destination as! PhotosCollectionController
        photosCollectionController.localAlbum = localAlbum
    }

    @IBAction func cancelButtonTap(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func uploadButtonTap(_ sender: UIBarButtonItem) {
        if let navigationController = navigationController as? PhotoPickerNavigationController {
            navigationController.childControllerUploadButtonTap()
        }
    }
}

extension AlbumsTableController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedLocalAlbum = localAlbums[indexPath.row]
        performSegue(withIdentifier: "showPhotosInLocalAlbum", sender: self)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return localAlbums.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: localAlbumCellID, for: indexPath) as! AlbumsTableCell

        cell.setup(localAlbums[indexPath.row])

        return cell
    }
}
