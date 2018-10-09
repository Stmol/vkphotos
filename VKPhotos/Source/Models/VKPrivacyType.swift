//
//  VKPrivacyType.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 28/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

protocol VKViewAndCommentPrivacy {
    var privacyView: [StringOrIntType]? { get }
    var privacyComment: [StringOrIntType]? { get }
}

extension VKViewAndCommentPrivacy {
    func getViewVKPrivacy() -> VKPrivacy? {
        guard let privacyView = self.privacyView else { return nil }
        return .init(privacyView)
    }

    func getCommentVKPrivacy() -> VKPrivacy? {
        guard let privacyComment = self.privacyComment else { return nil }
        return .init(privacyComment)
    }
}

enum PrivacyAccess: String {
    case OnlyMe = "only_me"
    case Nobody = "nobody"

    case All = "all"
    case Friends = "friends"
    case FriendsOfFriends = "friends_of_friends"
    case FriendsOfFriendsOnly = "friends_of_friends_only"

    //case Certain = "certain" TODO: Реализовать
    //case CertainLists = "certain_lists"

    static let rawValues = [
        All.rawValue,
        OnlyMe.rawValue,
        Nobody.rawValue,
        Friends.rawValue,
        FriendsOfFriends.rawValue,
        FriendsOfFriendsOnly.rawValue
    ]
}

struct VKPrivacy {
    static let `default` = VKPrivacy.init([.string(PrivacyAccess.All.rawValue)])

    private(set) var privacyAccess: PrivacyAccess?

    private(set) var allowedFriendIds = [Int]()
    private(set) var disallowedFriendIds = [Int]()

    private(set) var allowedFriendLists = [String]()
    private(set) var disallowedFriendLists = [String]()

    private var valuesOfPrivacy = [StringOrIntType]()

    var isPrivate: Bool {
        if privacyAccess == nil { return false }

        switch privacyAccess! {
        case .Nobody, .OnlyMe: return true
        default: return false
        }
    }

    var isFriendly: Bool {
        if privacyAccess == nil {
            return allowedFriendIds.isEmpty == false || allowedFriendLists.isEmpty == false
        }

        switch privacyAccess! {
        case .Friends, .FriendsOfFriends, .FriendsOfFriendsOnly: return true
        default: return false
        }
    }

    var isAllowedForSomeFriendsOnly: Bool {
        return !allowedFriendIds.isEmpty || !disallowedFriendIds.isEmpty
    }

    var isAllowedForFriendsListsOnly: Bool {
        return !allowedFriendLists.isEmpty || !disallowedFriendLists.isEmpty
    }

    var transcript: String {
        if privacyAccess != nil {
            switch privacyAccess! {
            case .All: return "All Users".localized()
            case .OnlyMe, .Nobody: return "Only Me".localized()
            case .Friends: return "Friends Only".localized()
            case .FriendsOfFriends, .FriendsOfFriendsOnly: return "Friends and Their Friends".localized()
            }
        }

        if !allowedFriendIds.isEmpty || !disallowedFriendIds.isEmpty {
            return "Certain Friends".localized()
        }

        if !allowedFriendLists.isEmpty || !disallowedFriendLists.isEmpty {
            return "Friends from Lists".localized()
        }

        return "" // TODO: Какая приватность по умолчанию?
    }

    init(_ valuesOfPrivacy: [StringOrIntType]) {
        if valuesOfPrivacy.isEmpty { print("💎 Privacy field is empty!"); return }
        self.valuesOfPrivacy = valuesOfPrivacy

        if
            case .string(let access)? = self.valuesOfPrivacy.first,
            PrivacyAccess.rawValues.contains(where: { $0 == access }) {
            privacyAccess = PrivacyAccess(rawValue: access) ?? nil
            self.valuesOfPrivacy.removeFirst()
        }

        for value in self.valuesOfPrivacy {
            switch value {
            // Collection with user IDs
            case .int(let id):
                if id < 0 {
                    disallowedFriendIds.append(abs(id))
                } else {
                    allowedFriendIds.append(id)
                }

            // Collection with IDs of lists
            case .string(var list):
                guard let firstChar = list.first else { continue }
                if firstChar == "-" {
                    list.removeFirst(); disallowedFriendLists.append(list)
                } else {
                    allowedFriendLists.append(list)
                }
            }
        }
    }
}
