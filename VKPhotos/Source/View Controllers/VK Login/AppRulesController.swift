//
//  AppRulesController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 26/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class AppRulesController: UIViewController {
    @IBAction func okButtonTap(_ sender: UIButton) {
        dismiss(animated: true)
    }
    @IBOutlet weak var rulesTextLabel: UILabel!
    @IBOutlet weak var linkToVKAPILabel: UILabel! {
        didSet {
            let attributedText = NSMutableAttributedString(string: linkToVKAPILabel.text!)
            attributedText.addAttribute(
                .font, value: UIFont.systemFont(ofSize: 15), range: NSRange(location: 0, length: attributedText.string.count)
            )
            attributedText.addAttribute(
                .link, value: "https://vk.com/dev/permissions", range: NSRange(location: 60, length: attributedText.string.count - 60)
            )
            linkToVKAPILabel.text = nil
            linkToVKAPILabel.attributedText = attributedText
            linkToVKAPILabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onLinkToVKAPILabelTap)))
        }
    }

    @objc func onLinkToVKAPILabelTap(_ sender: UILabel) {
        if let url = URL(string: "https://vk.com/dev/permissions") {
            UIApplication.shared.open(url, options: [:])
        }
    }
}
