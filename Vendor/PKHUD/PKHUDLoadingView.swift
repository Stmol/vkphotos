//
//  PKHUDLoadingView.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 26/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

open class PKHUDLoadingView: PKHUDSquareBaseView, PKHUDAnimating  {

    public init(title: String? = nil, subtitle: String? = nil) {
        super.init(image: nil, title: nil, subtitle: nil)

        let bounds = CGRect(origin: .zero, size: CGSize(width: 38, height: 38))
        let view = STSubmitLoading(frame: bounds)
        view.show(self)
        view.startLoading()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public func startAnimation() {}

    public func stopAnimation() {}

}
