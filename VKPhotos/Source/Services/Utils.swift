//
//  Utils.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 02/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

enum RequestState {
    case execute, done, fail
}

struct DeviceOrientation {
    static var isLandscape: Bool {
        return UIDevice.current.orientation.isValidInterfaceOrientation
            ? UIDevice.current.orientation.isLandscape
            : UIApplication.shared.statusBarOrientation.isLandscape
    }

    static var isPortrait: Bool {
        return UIDevice.current.orientation.isValidInterfaceOrientation
            ? UIDevice.current.orientation.isPortrait
            : UIApplication.shared.statusBarOrientation.isPortrait
    }
}

func getVKTermsURL() -> String {
    var url = "https://m.vk.com/terms?api_view=1"

    let preferredLanguage = NSLocale.preferredLanguages[0]
    if preferredLanguage.starts(with: "ru") {
        url += "&lang=ru"
    } else {
        url += "&lang=en"
    }

    return url
}

func getVKPrivacyURL() -> String {
    var url = "https://m.vk.com/privacy?api_view=1"

    let preferredLanguage = NSLocale.preferredLanguages[0]
    if preferredLanguage.starts(with: "ru") {
        url += "&lang=ru"
    } else {
        url += "&lang=en"
    }

    return url
}

func isDevicePlus() -> Bool {
    return UIScreen.main.bounds.width > 375.0
}

func dispatch(_ name: Notification.Name, _ event: Any?) {
    print("🔥 \(name.rawValue)")
    NotificationCenter.default.post(name: name, object: event)
}

func startListen(_ name: Notification.Name, _ observer: Any, _ callback: Selector) {
    NotificationCenter.default.addObserver(observer, selector: callback, name: name, object: nil)
}

public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG

    var idx = items.startIndex
    let endIdx = items.endIndex

    repeat {
        Swift.print("APP: \(items[idx])", separator: separator, terminator: idx == (endIdx - 1) ? terminator : separator)
        idx += 1
    } while idx < endIdx

#endif
}
