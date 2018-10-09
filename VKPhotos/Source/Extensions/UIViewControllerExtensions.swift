//
// Created by Yury Smidovich on 11/02/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Firebase

extension UIViewController {

    var className: String {
        return NSStringFromClass(self.classForCoder).components(separatedBy: ".").last!
    }

    func showErrorNotification(_ text: String, _ onDismiss: (() -> Void)? = nil) {
        showNotification(.error, text, onDismiss)
    }

    func showWarningNotification(with message: String = "Something wrong", dismiss: (() -> Void)? = nil) {
        showNotification(.warning, message, dismiss)
    }

    func showNotification(_ type: GSMessageType, _ text: String, _ onDismiss: (() -> Void)? = nil) {
        self.showMessage(text, type: type, options: [
            .animation(GSMessageAnimation.slide),
            .animationDuration(0.2),
            .autoHide(true),
            .autoHideDelay(1.95),
            .height(42.0),
            .padding(.init(top: 10, left: 30, bottom: 10, right: 30)),
            .position(.top),
            .textAlignment(.center),
            .textColor(.white),
            .textNumberOfLines(1),
            .handleTap { onDismiss?() }
        ])

        Analytics.logEvent(AnalyticsEvent.ShowAlert, parameters: [
            "type": type.rawValue,
            "text": text,
            "source": className
        ])
    }

    func getVisibleViewController(_ rootViewController: UIViewController?) -> UIViewController? {
        if rootViewController?.presentedViewController == nil { return rootViewController }

        if let presented = rootViewController?.presentedViewController {
            if presented.isKind(of: UINavigationController.self) {
                let navigationController = presented as! UINavigationController
                return navigationController.viewControllers.last!
            }

            if presented.isKind(of: UITabBarController.self) {
                let tabBarController = presented as! UITabBarController
                return tabBarController.selectedViewController!
            }

            return getVisibleViewController(presented)
        }

        return nil
    }

}
