//
//  VKUserManager.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 23/09/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Firebase

class VKUserBanManager {

    static let shared = VKUserBanManager()
    private init() {
        if let ids = UserDefaults.standard[UserDefaultsKey] as? [Int] {
            banned = Set<Int>(ids)
        }
    }

    private let FetchBannedPerPage = 1
    private let UserDefaultsKey = "vk_banned_ids"

    private var banned = Set<Int>()
    private let api = VKApiClient()

    func ban(id: Int) -> Bool {
        print("ID to block: \(id)")
        if banned.insert(id).inserted {
            UserDefaults.standard[UserDefaultsKey] = Array(banned)
            dispatch(.vkUserBlocked, VKUserBlockedEvent(id: id))
            Analytics.logEvent(AnalyticsEvent.UserBlock, parameters: nil)
            return true
        }

        return false
    }

    func unban(id: Int) -> Bool {
        print("ID to unblock: \(id)")
        if banned.remove(id) != nil {
            UserDefaults.standard[UserDefaultsKey] = Array(banned)
            dispatch(.vkUserUnblocked, VKUserUnblockedEvent(id: id))
            Analytics.logEvent(AnalyticsEvent.UserUnblock, parameters: nil)
            return true
        }

        return false
    }

    func isBanned(id: Int) -> Bool {
        return banned.contains(id)
    }

}
