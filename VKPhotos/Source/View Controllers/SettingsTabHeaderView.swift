//
//  SettingsTabHeaderView.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 14/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class SettingsTabHeaderView: UIView {
    @IBOutlet weak var userAvatarImageView: UIImageView! {
        didSet {
            userAvatarImageView.layer.cornerRadius = CGFloat(userAvatarImageView.frame.size.width / 2)
            userAvatarImageView.layer.backgroundColor = UIColor.white.cgColor
        }
    }

    @IBOutlet weak var userNameLabel: UILabel!
}
