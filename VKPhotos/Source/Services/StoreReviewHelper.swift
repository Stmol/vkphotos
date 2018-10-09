//
// Created by Yury Smidovich on 10/09/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import StoreKit
import Firebase

struct StoreReviewHelper {
    static let UserDefaultsKey = "APP_OPENED_COUNT"

    static func incrementAppOpenedCount() {
        guard var appOpenCount = UserDefaults.standard[self.UserDefaultsKey] as? Int else {
            UserDefaults.standard[self.UserDefaultsKey] = 1
            return
        }

        appOpenCount += 1
        UserDefaults.standard[self.UserDefaultsKey] = appOpenCount
    }

    static func checkAndAskForReview() {
        guard let appOpenCount = UserDefaults.standard[self.UserDefaultsKey] as? Int else {
            UserDefaults.standard[self.UserDefaultsKey] = 1
            return
        }

        switch appOpenCount {
        case 5, 30:
            StoreReviewHelper().requestReview(appOpenCount)
        case _ where appOpenCount % 100 == 0:
            StoreReviewHelper().requestReview(appOpenCount)
        default:
            break
        }
    }

    fileprivate func requestReview(_ count: Int) {
        SKStoreReviewController.requestReview()
        Analytics.logEvent(AnalyticsEvent.RequestReview, parameters: ["app_opened_count": count])
    }
}
