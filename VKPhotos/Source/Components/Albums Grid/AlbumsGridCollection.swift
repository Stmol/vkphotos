//
// Created by Yury Smidovich on 09/03/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Hydra
import DeepDiff

protocol AlbumsGridDelegate: class {
    func albumDidSelected(vkAlbum: VKAlbum)
    func albumDelete(_ vkAlbum: VKAlbum)
}

class AlbumsGridCollection: InfinityGrid {
    fileprivate let SPACING_BETWEEN_CELLS = CGFloat(15)
    fileprivate let FooterReuseID = "AlbumsGridFooterReusableView"

    private(set) var vkAlbums: [VKAlbum] = []
    private(set) var isEditMode = false {
        didSet { reloadData() } // TODO: Подумать как менее затратно перерисовывать
    }

    fileprivate weak var albumsGridDelegate: AlbumsGridDelegate?

    lazy var footer: InfinityGridFooter = { return .fromNib() }()

    func setup(withDelegate delegate: AlbumsGridDelegate) {
        register(UINib(nibName: "AlbumsGridCell", bundle: nil), forCellWithReuseIdentifier: AlbumsGridCellId)
        register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: FooterReuseID)
        alwaysBounceVertical = true

        self.delegate = self
        self.dataSource = self
        self.albumsGridDelegate = delegate
    }

    func toggleEditMode() {
        isEditMode = !isEditMode
    }
}

// MARK: Data manipulation -
extension AlbumsGridCollection {
    func reloadData(_ vkAlbums: [VKAlbum], _ completion: (() -> Void)? = nil) {
        let changes = diff(old: self.vkAlbums, new: vkAlbums)
        self.vkAlbums = vkAlbums

        print("📔 Albums reload")
        reload(changes: changes) { [weak self] _ in
            self?.reloadData() // TODO: Надо поглядывать на поведение этой штуки
            completion?()
        }
    }
}

extension AlbumsGridCollection: UIScrollViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        albumsGridDelegate?.albumDidSelected(vkAlbum: vkAlbums[indexPath.item])
    }
}

extension AlbumsGridCollection: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return vkAlbums.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumsGridCellId, for: indexPath) as! AlbumsGridCell

        let vkAlbum = vkAlbums[indexPath.item]

        cell.isEditable = isEditMode
        cell.setup(vkAlbum)
        cell.onDeleteTap = { [weak self] in
            self?.albumsGridDelegate?.albumDelete(vkAlbum)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionElementKindSectionFooter else { fatalError("Unexpected element kind") } // TODO Check

        let reusableFooterSection = collectionView.dequeueReusableSupplementaryView(
            ofKind: UICollectionElementKindSectionFooter,
            withReuseIdentifier: FooterReuseID,
            for: indexPath
        )

        footer.frame.size = CGSize(width: collectionView.bounds.width, height: 60)
        reusableFooterSection.addSubview(footer)

        return reusableFooterSection
    }
}

extension AlbumsGridCollection: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 60)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacingBetweenCells = SPACING_BETWEEN_CELLS * 3
        let cellWidth = floor((collectionView.bounds.width - spacingBetweenCells) / 2)

        return CGSize(width: cellWidth, height: cellWidth + 50)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return SPACING_BETWEEN_CELLS - 5
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return SPACING_BETWEEN_CELLS
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if vkAlbums.isEmpty {
            return UIEdgeInsets.zero
        }

        return UIEdgeInsets(top: 15, left: SPACING_BETWEEN_CELLS, bottom: 0, right: SPACING_BETWEEN_CELLS)
    }
}
