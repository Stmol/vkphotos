//
//  PhotosGridCell.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Kingfisher
import BEMCheckBox

let PhotosGridCellId = "PhotosGridCell"

class PhotosGridCell: UICollectionViewCell, BEMCheckBoxDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var checkBox: BEMCheckBox! {
        didSet {
            checkBox.isHidden = true

            checkBox.layer.shadowRadius = 2.0
            checkBox.layer.shadowOpacity = 0.4
            checkBox.layer.shadowOffset = CGSize(width: 0, height: 1)
            checkBox.layer.shadowColor = UIColor.darkGray.cgColor

            checkBox.onAnimationType = .bounce
            checkBox.offAnimationType = .bounce

            checkBox.delegate = self
        }
    }

    var onCheckboxTap: ((Bool) -> Void)?

    override func prepareForReuse() {
        imageView.alpha = 1
        imageView.image = nil
        imageView.removeSubviews()

        checkBox.isHidden = true
        checkBox.on = false
    }

    func setup(_ vkPhoto: VKPhoto, _ isSelectable: Bool = false) {
        if let imageUrl = getImageUrl(byVKPhoto: vkPhoto) {
            var options = [KingfisherOptionsInfoItem]()
            options.append(.transition(.fade(0.3)))

            if vkPhoto.isBanned {
                options.append(.processor(BlurImageProcessor(blurRadius: 30)))
                addInvisibleIcon()
            }

            // TODO Make default image if it doesnt exists in VKPhoto
            imageView.kf.setImage(with: URL(string: imageUrl), options: options)
        }

        checkBox.isHidden = !isSelectable
    }

    func didTap(_ checkBox: BEMCheckBox) {
        onCheckboxTap?(checkBox.on)
        updateImageAlpha()
    }

    func uncheck(_ isAnim: Bool = true) {
        checkBox.setOn(false, animated: isAnim)
        updateImageAlpha()
    }

    func check(_ isAnim: Bool = true) {
        checkBox.setOn(true, animated: isAnim)
        updateImageAlpha()
    }

    private func addInvisibleIcon() {
        let invisibleIcon = UIImageView(image: UIImage(named: "invisible"))
        invisibleIcon.tintColor = .white
        imageView.addSubview(invisibleIcon)
        invisibleIcon.anchorCenterSuperview()
    }

    private func updateImageAlpha() {
        imageView.alpha = checkBox.on ? 0.5 : 1
    }

    private func getImageUrl(byVKPhoto vkPhoto: VKPhoto) -> String? {
        return vkPhoto.getVKSize(byType: "x")?.getUrl()
    }
}
