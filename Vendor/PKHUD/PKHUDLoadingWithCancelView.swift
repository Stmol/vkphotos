//
// Created by Yury Smidovich on 01/09/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Firebase

open class PKHUDLoadingWithCancelView: PKHUDSquareBaseView, PKHUDAnimating
{
    var onCancelCrossTap: (() -> Void)? = nil
    private var afterCancellationHandler: (() -> Void)? = nil

    public init(delayBeforeShowCross: Double = 0.3, afterCancellation: (() -> Void)? = nil) {
        super.init(image: nil, title: nil, subtitle: nil)
        self.afterCancellationHandler = afterCancellation

        let bounds = CGRect(origin: .zero, size: CGSize(width: 38, height: 38))
        let view = STSubmitLoading(frame: bounds)
        view.show(self)
        view.startLoading()

        Timer.scheduledTimer(withTimeInterval: delayBeforeShowCross, repeats: false) { [weak self] _ in
            guard let this = self else { return }

            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(this.onTap)))
            view.showCancelCross()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    @objc private func onTap() {
        onCancelCrossTap?()
        Analytics.logEvent(AnalyticsEvent.HUDCancelTap, parameters: nil)
        afterCancellationHandler?()
    }

    public func startAnimation() {}

    public func stopAnimation() {}
}
