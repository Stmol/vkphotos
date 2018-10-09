//
//  CounterBadge.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 11/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class CounterBadge {
    private let baseColor = UIColor(red: 0, green: 122/255.0, blue: 255/255.0, alpha: 1.0)
    private let alertColor = UIColor.red
    private let button: UIButton

    var view: UIView {
        return button
    }

    init(with text: String, isAlertState: Bool = false) {
        button = UIButton()
        button.frame.size.height = 20
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.layer.cornerRadius = ((button.frame.size.height + 10) / 2) - 1
        button.isEnabled = false

        button.backgroundColor = isAlertState ? alertColor : baseColor
    }

    func pop(with text: String, isAlertState: Bool = false) {
        button.backgroundColor = isAlertState ? alertColor : baseColor
        button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: CGFloat(0.9),
            initialSpringVelocity: CGFloat(6.0),
            animations: {
                self.button.transform = CGAffineTransform.identity
                self.button.setTitle(text, for: .normal)
                self.button.sizeToFit()
        })
    }

    func shake() {
        button.shakeAnimation()
    }
}
