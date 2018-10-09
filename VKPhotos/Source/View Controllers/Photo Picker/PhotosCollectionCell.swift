//
// Created by Yury Smidovich on 10/05/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import M13Checkbox

class PhotosCollectionCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var checkbox: M13Checkbox! {
        didSet {
            checkbox.boxType = .circle
            checkbox.markType = .checkmark
            checkbox.boxLineWidth = 1.5
            checkbox.checkmarkLineWidth = 2.0
            checkbox.secondaryTintColor = UIColor.white

            checkbox.layer.shadowRadius = 2.0
            checkbox.layer.shadowOpacity = 0.4
            checkbox.layer.shadowOffset = CGSize(width: 0, height: 1)
            checkbox.layer.shadowColor = UIColor.darkGray.cgColor

            checkbox.stateChangeAnimation = .expand(.fill)
            checkbox.animationDuration = 0.15

            checkbox.isUserInteractionEnabled = false
        }
    }

    override func prepareForReuse() {
        checkbox.setCheckState(.unchecked, animated: false)
        imageView.alpha = 1.0
    }

    func checkPhoto() {
        guard checkbox.checkState == .unchecked else { return }

        checkbox.setCheckState(.checked, animated: true)
        imageView.alpha = 0.7
    }

    func uncheckPhoto() {
        guard checkbox.checkState == .checked else { return }

        checkbox.setCheckState(.unchecked, animated: true)
        imageView.alpha = 1
    }
}
