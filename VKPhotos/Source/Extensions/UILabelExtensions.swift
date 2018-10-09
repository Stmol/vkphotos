//
//  UILabelExtensions.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 20/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

extension UILabel {

    // TODO: Потенциально текучий код
    func heightForView(numberOfLines: Int = 0) -> CGFloat {
        let label: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: frame.width, height: CGFloat.greatestFiniteMagnitude))
        label.numberOfLines = numberOfLines
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.font = font
        label.text = text
        label.attributedText = attributedText
        label.sizeToFit()

        return label.frame.height
    }

}
