//
//  VKAlbumsTableCell.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 01/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Kingfisher

class VKAlbumsTableCell: UITableViewCell {
    @IBOutlet weak var albumTitle: UILabel!
    @IBOutlet weak var albumCoverImage: UIImageView! {
        didSet {
            albumCoverImage.layer.cornerRadius = 5
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        albumCoverImage.image = nil
    }

    func setup(_ vkAlbum: VKAlbum) {
        albumTitle.text = vkAlbum.title

        if let imageUrl = vkAlbum.getVKSize(byType: "m")?.getUrl() {
            albumCoverImage.kf.setImage(with: URL(string: imageUrl)!)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.accessoryType = selected ? .checkmark : .none
        super.setSelected(false, animated: true)
    }
}
