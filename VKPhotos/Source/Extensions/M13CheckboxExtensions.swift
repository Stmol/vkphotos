//
//  M13CheckBoxExtensions.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 11/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

// TODO if can import
import M13Checkbox

extension M13Checkbox {

    func pop(scale: CGFloat = 1.3) {
        self.transform = CGAffineTransform(scaleX: scale, y: scale)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: CGFloat(0.9),
            initialSpringVelocity: CGFloat(6.0),
            animations: {
                self.transform = CGAffineTransform.identity
        })
    }

}
