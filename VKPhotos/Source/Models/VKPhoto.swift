//
//  VKPhoto.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 28/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import VKSdkFramework
import Crashlytics

struct VKPhoto: Codable, VKSizable, VKEntityHashable {

    let id: Int
    var albumId: Int
    let ownerId: Int
    let date: Int
    var text: String
    let sizes: [VKSize]?
    let postId: Int?
    var likes: VKLikes?
    let reposts: VKReposts?
    let canComment: Int?
    let accessKey: String?
    //let realOffset: Int?

    // Мои кастомные поля в апи
    let _isFav: Bool? // Помечается true/false только при запросе избранных фото

    // VK Developers are crazy guys
    let width: Int?
    let height: Int?
    //    let photo_75: String?
    //    let photo_130: String?
    //    let photo_604: String?
    //    let photo_807: String?
    //    let photo_1280: String?
    //    let photo_2560: String?

    enum CodingKeys: String, CodingKey {
        case id, date, text, sizes, likes, reposts
        case width, height
        case albumId = "album_id"
        case ownerId = "owner_id"
        case postId = "post_id"
        case canComment = "can_comment"
        case _isFav = "is_fav"
        case accessKey = "access_key"

        // photo_2560, photo_1280, photo_807, photo_604, photo_130, photo_75
        // case realOffset = "real_offset"
    }

    // Динамические поля
    var isDeleted: Bool = false
    var ownerInfo: VKPhotoInfo.Owner?

    var isFav: Bool {
        return _isFav != nil && _isFav == true
    }

    var isEditableCaption: Bool {
        return albumId != -15 && albumId != -6
    }

    func getSizes() -> [VKSize]? {
        return sizes
    }

}

// MARK: Mutating
extension VKPhoto {

    var isLiked: Bool {
        return likes != nil && likes!.isLiked
    }

    var isInfoExist: Bool { // TODO!!! Очень важно разделить эти поля
        return likes != nil && ownerInfo != nil
    }

    var isBanned: Bool {
        return VKUserBanManager.shared.isBanned(id: ownerId)
    }

    var isCurrentUserOwner: Bool {
        if let accessToken = VKSdk.accessToken(), let userId = accessToken.userId {
            return userId == String(ownerId)
        }

        return false
    }

    mutating func updateInfo(_ info: VKPhotoInfo) {
        ownerInfo = info.owner
        guard let userLikes = info.likes.liked, let count = info.likes.count else {
            Crashlytics.sharedInstance().recordError(
                VKApiClientErrors.ResponseDataUnexpected,
                withAdditionalUserInfo: ["photo": "\(self.ownerId)_\(self.id)"]
            )

            print("⛔️ USER LIKES IS EMPTY: \(info.id) ⛔️"); return
        }

        likes = VKLikes(userLikes: userLikes, count: count)
    }

    mutating func like(_ count: Int) {
        likes = VKLikes(userLikes: 1, count: count)
    }

    mutating func dislike(_ count: Int) {
        likes = VKLikes(userLikes: 0, count: count)
    }

}
