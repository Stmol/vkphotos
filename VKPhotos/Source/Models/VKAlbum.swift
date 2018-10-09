//
//  VKAlbum.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 28/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

struct VKAlbum: Decodable, VKEntityHashable, VKSizable, VKViewAndCommentPrivacy {

    enum SystemName: String {
        case profile, wall, saved
    }

    let id: Int
    let thumbId: Int
    let ownerId: Int
    let title: String
    let description: String?
    let photosCount: Int
    let canUpload: Int?
    let thumbSrc: String?
    let sizes: [VKSize]?
    let privacyView: [StringOrIntType]?
    let privacyComment: [StringOrIntType]?

    enum CodingKeys: String, CodingKey {
        case id, title, description, sizes
        case thumbId = "thumb_id"
        case ownerId = "owner_id"
        case photosCount = "size"
        case canUpload = "can_upload"
        case thumbSrc = "thumb_src"
        case privacyView = "privacy_view"
        case privacyComment = "privacy_comment"
    }

    var isSystem: Bool { return id <= 0 }
    var systemName: SystemName? {
        switch id {
        case -6: return .profile
        case -7: return .wall
        case -15: return .saved
        default: return nil
        }
    }

    var isAlbumSaved: Bool {
        return systemName != nil && systemName! == .saved
    }

    func getSizes() -> [VKSize]? {
        return sizes
    }

}

struct VKAlbumDTO {

    let vkAlbum: VKAlbum? // Если прицепили существующий альбом, значит ДТО изменяет его

    let title: String
    let description: String?
    let viewPrivacy: VKPrivacy // По дефолту "all"
    let commentPrivacy: VKPrivacy // По дефолту "all"

    init(
        _ title: String,
        _ description: String? = nil,
        _ vkAlbum: VKAlbum? = nil,
        _ viewPrivacy: VKPrivacy = .default,
        _ commentPrivacy: VKPrivacy = .default
        ) {

        self.title = title
        self.description = description
        self.viewPrivacy = viewPrivacy
        self.commentPrivacy = commentPrivacy
        self.vkAlbum = vkAlbum
    }

}
