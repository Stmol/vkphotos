//
//  PhotosGridCollection.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import DeepDiff
import Kingfisher

protocol PhotosGridDelegate: class {
    func tapVKPhoto(inCell cell: PhotosGridCell, atIndex: Int)
    func onScrollEndReached()
    func onRefresh()

    func selectVKPhoto(_ vkPhoto: VKPhoto, _ result: ((Bool) -> Void))
    func deselectVKPhoto(_ vkPhoto: VKPhoto, _ result: ((Bool) -> Void))
    func isVKPhotoSelected(_ vkPhoto: VKPhoto) -> Bool
}

class PhotosGridCollection: InfinityGrid {
    deinit {
        print("[💣] PhotosGridCollection")
    }

    private let FooterReusableViewID = "PhotosGridFooterReusableView"
    private let HeaderUploadPhotoViewID = "PhotosGridUploadPhotoHeader"

    fileprivate let FooterHeight = CGFloat(60)

    override var onEndReachedThreshold: CGFloat { return 350 + FooterHeight }
    private weak var photosGridDelegate: PhotosGridDelegate?

    // Флаг состояния перезагрузки сетки
    // Если true значит сетка в данный момент анимируется
    private var isReloading = false

    private(set) var vkPhotos = [VKPhoto]()
    private(set) var itemsPerRow: Int = 4
    private(set) var isSelectable = false

    lazy var footer: InfinityGridFooter = { return .fromNib() }()

    func setup(_ photosGridDelegate: PhotosGridDelegate, _ itemsPerRow: Int? = nil) {
        register(UINib(nibName: "PhotosGridCell", bundle: nil), forCellWithReuseIdentifier: PhotosGridCellId)
        register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: FooterReusableViewID)

        delegate = self
        dataSource = self
        prefetchDataSource = self
        self.photosGridDelegate = photosGridDelegate

        if let itemsPerRow = itemsPerRow {
            self.itemsPerRow = itemsPerRow
        }
    }

    func toggleIsSelectable(to value: Bool) {
        isSelectable = value

        if !isReloading {
            // Зачем это нужно?
            // Когда мы переключаем режим выбора в сетке, мы должны обновить ячейки вызвав какой-нибудь reloadData
            // Но в этот момент у нас уже может быть запущен reload, например от DeepDiff'a,
            // в конце которого так и так вызывается reloadData.
            //
            // И поэтому, если мы вызовем параллельно еще один reloadData
            // - могут возникнуть конфликты вплоть до падения аппки
            reloadData()
        }
    }
}

// MARK: Data manipulation -
extension PhotosGridCollection {
    // Этот метод существует потому что при вставке новых фото нам не нужно вычислять диф
    // Но по хорошему должен остаться только один метод для обновления списка - reloadPhotos
    //
    // Помни что @param photosToInsert должен приходить с isDeleted = false
    func insertPhotos(_ photosToInsert: [VKPhoto], then completion: (() -> Void)? = nil) {
        // TODO: Нужно соблюсти консистентность данных в стейте и в коллекции
        let (start, end) = (vkPhotos.count, vkPhotos.count + photosToInsert.count)
        let indexPaths = (start..<end).map({ return IndexPath(row: $0, section: 0) })

        self.vkPhotos.append(contentsOf: photosToInsert)
        self.isReloading = true

        performBatchUpdates({ self.insertItems(at: indexPaths) }) { [weak self] _ in
            self?.isReloading = false
            print("🖼 Photos: Did Insert - \(String(describing: self?.photosGridDelegate.self)))")
            completion?()
        }
    }

    // Помни что @param newVKPhotos должен приходить с isDeleted = false
    func reloadPhotos(with newVKPhotos: [VKPhoto], then completion: (() -> Void)? = nil) {
        let changes = diff(old: self.vkPhotos, new: newVKPhotos)

        self.vkPhotos = newVKPhotos
        self.isReloading = true

        reload(changes: changes, completion: { [weak self] _ in
            print("🖼 Photos: Did Reload - \(String(describing: self?.photosGridDelegate.self)))")

            self?.reloadData()
            self?.isReloading = false

            completion?()
        })
    }
}

extension PhotosGridCollection: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return vkPhotos.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
//        case UICollectionElementKindSectionHeader:
//            let header = collectionView.dequeueReusableSupplementaryView(
//                ofKind: kind,
//                withReuseIdentifier: HeaderUploadPhotoViewID,
//                for: indexPath)
//
//            return header
        case UICollectionElementKindSectionFooter:
            let reusableFooter = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: FooterReusableViewID,
                for: indexPath)

            footer.frame.size = CGSize(width: collectionView.bounds.width, height: 60)
            reusableFooter.addSubview(footer)

            return reusableFooter
        default:
            assert(false, "Unexpected element kind")
        }

        fatalError("Cant find valid view") // TODO Check
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotosGridCellId, for: indexPath) as! PhotosGridCell

        guard indexPath.item >= 0 && indexPath.item < vkPhotos.count else {
            // TODO: Тут падает по index out of a range при удалении целого альбома - что за херня?
            // пришлось воткнуть проверку, но это явно косяк с паралелизмом
            return cell
        }

        let vkPhoto = vkPhotos[indexPath.item]
        cell.setup(vkPhoto, isSelectable)
        cell.onCheckboxTap = { [weak self] isChecked in
            switch isChecked {
            case true:
                self?.photosGridDelegate?.selectVKPhoto(vkPhoto) { isSelected in
                    if !isSelected { cell.uncheck(false) }
                }
            case false:
                self?.photosGridDelegate?.deselectVKPhoto(vkPhoto) { isDeselected in
                    if !isDeselected { cell.check(false) }
                }
            }
        }

        if let delegate = photosGridDelegate, delegate.isVKPhotoSelected(vkPhoto) {
            cell.check(false)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotosGridCell else { return }
        photosGridDelegate?.tapVKPhoto(inCell: cell, atIndex: indexPath.item)
    }
}

extension PhotosGridCollection: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: FooterHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellSpaceWidth: CGFloat = isDevicePlus() ? 6 : 3
        // TODO: Правильно вычислить пробелы между ячейками
        let itemSize = floor((collectionView.bounds.width - cellSpaceWidth) / CGFloat(itemsPerRow))

        return CGSize(width: itemSize, height: itemSize)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return isDevicePlus() ? 2 : 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return isDevicePlus() ? 2 : 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let inset: CGFloat = isDevicePlus() ? 2 : 1
        return UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
    }
}

extension PhotosGridCollection: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            if let cell = cellForItem(at: indexPath) as? PhotosGridCell {
                cell.imageView.kf.cancelDownloadTask()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
//        let imageUrlsToPrefetch = indexPaths.flatMap { indexPath -> URL? in
//            if let imageUrl = vkPhotos[indexPath.item].getVKSize(byType: "x")?.getUrl() {
//                return URL(string: imageUrl)
//            }
//
//            return nil
//        }
//
//        if !imageUrlsToPrefetch.isEmpty {
//            ImagePrefetcher(urls: imageUrlsToPrefetch).start()
//        }
    }
}
