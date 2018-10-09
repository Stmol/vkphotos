//
//  AlbumsTableCell.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 15/05/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Photos

class AlbumsTableCell: UITableViewCell {
    @IBOutlet weak var albumCoverImageView: UIImageView!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet weak var albumPhotosCountLabel: UILabel!

    var album: LocalAlbum!

    override func prepareForReuse() {
        self.albumCoverImageView.image = nil
    }

    func setup(_ album: LocalAlbum) {
        albumTitleLabel.text = album.name
        albumPhotosCountLabel.text = String(album.photosCount)

        getThumbForAlbum(localAlbum: album) { image in
            guard let image = image else { return }
            self.albumCoverImageView.image = image
        }
    }

    private func getThumbForAlbum(localAlbum: LocalAlbum, result: @escaping (UIImage?) -> Void) {
        guard let asset = localAlbum.thumbAsset else { return }

        let options = PHImageRequestOptions()
        //options.isNetworkAccessAllowed = false
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options) { image, _ in result(image) }
    }
}
