//
//  AlbumsGridCell.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 10/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

let AlbumsGridCellId = "AlbumsGridCell"

class AlbumsGridCell: UICollectionViewCell {
    @IBOutlet weak var deleteButton: UIButton! {
        didSet {
            deleteButton.layer.shadowRadius = 1
            deleteButton.layer.shadowOpacity = 0.2
            deleteButton.layer.shadowOffset = CGSize(width: 0, height: 1)
            deleteButton.layer.shadowColor = UIColor.darkGray.cgColor
            deleteButton.alpha = 0
        }
    }
    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            imageView.layer.cornerRadius = 5
            imageView.clipsToBounds = true
        }
    }

    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet weak var albumSizeLabel: UILabel!
    @IBOutlet weak var privacyIconButton: UIButton! {
        didSet {
            privacyIconButton.layer.shadowRadius = 2
            privacyIconButton.layer.shadowOpacity = 0.6
            privacyIconButton.layer.shadowOffset = CGSize(width: 0, height: 1)
            privacyIconButton.layer.shadowColor = UIColor.darkGray.cgColor
        }
    }

    @IBAction func deleteButtonTap(_ sender: UIButton) {
        guard isEditable else { return }
        onDeleteTap?()
    }

    // Находится ли ячейка в режиме редактирования
    var isEditable = false
    var onDeleteTap: (() -> Void)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let translatedPoint = deleteButton.convert(point, from: self)

        if deleteButton.bounds.contains(translatedPoint) {
            return deleteButton.hitTest(translatedPoint, with: event)
        }

        return super.hitTest(point, with: event)
    }

    override func prepareForReuse() {
        // imageView.kf.cancelDownloadTask()
        imageView.image = nil
        privacyIconButton.isHidden = true

        imageView.alpha = 1
        albumSizeLabel.alpha = 1
        albumTitleLabel.alpha = 1
        deleteButton.alpha = 0
    }

    func setup(_ vkAlbum: VKAlbum) {
        albumTitleLabel.text = vkAlbum.title
        albumSizeLabel.text = String(vkAlbum.photosCount)

        if vkAlbum.isSystem {
            disableSystemAlbum()
        } else {
            deleteButton.alpha = isEditable ? 1 : 0
        }

        if let imageUrl = vkAlbum.getVKSize(byType: "x")?.getUrl() {

            imageView.kf.setImage(with: URL(string: imageUrl), options: [.transition(.fade(0.2))])
        }

        if let privacyView = vkAlbum.getViewVKPrivacy() {
            if privacyView.isPrivate {
                privacyIconButton.setImage(UIImage(named: "locked"), for: .normal)
                privacyIconButton.isHidden = false
            }

            if privacyView.isFriendly {
                privacyIconButton.setImage(UIImage(named: "friends"), for: .normal)
                privacyIconButton.isHidden = false
            }
        }
    }

    fileprivate func disableSystemAlbum() {
        imageView.alpha = isEditable ? 0.6 : 1
        albumSizeLabel.alpha = isEditable ? 0.6 : 1
        albumTitleLabel.alpha = isEditable ? 0.6 : 1
        deleteButton.alpha = 0
    }
}
