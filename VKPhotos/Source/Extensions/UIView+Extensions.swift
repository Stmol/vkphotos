//
//  UIView.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 25/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

extension UIView {

    public class func fromNib<T: UIView>() -> T {
        return Bundle.main.loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as! T
    }

    func shakeAnimation() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.05
        animation.repeatCount = 2
        animation.autoreverses = true

        let fromPoint = CGPoint(x: center.x - 5, y: center.y)
        let fromValue = NSValue(cgPoint: fromPoint)

        let toPoint = CGPoint(x: center.x + 5, y: center.y)
        let toValue = NSValue(cgPoint: toPoint)

        animation.fromValue = fromValue
        animation.toValue = toValue

        layer.add(animation, forKey: "position")
    }

}
