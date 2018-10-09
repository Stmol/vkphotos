//
// Created by Yury Smidovich on 21/02/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation

struct VKResponseCollection<VKEntity: Decodable>: Decodable {
    let data: Response

    enum CodingKeys: String, CodingKey {
        case data = "response"
    }

    struct Response: Decodable {
        let count: Int
        let items: [VKEntity]
    }
}

struct VKResponseData<T: Decodable>: Decodable {
    let data: T

    enum CodingKeys: String, CodingKey {
        case data = "response"
    }
}

struct VKLikes: Codable {
    var userLikes: Int
    var count: Int

    enum CodingKeys: String, CodingKey {
        case userLikes = "user_likes"
        case count
    }

    var isLiked: Bool { return userLikes == 1 }
}

struct VKPhotoInfo: Codable {
    struct Owner: Codable {
        let id: Int
        let name: String
        let link: String

        enum CodingKeys: String, CodingKey {
            case id, name, link
        }
    }

    struct Likes: Codable {
        // Могут приехать `null` потому что не будет доступа к фотке
        let liked: Int?
        let count: Int?

        enum CodingKeys: String, CodingKey {
            case liked, count
        }
    }

    let id: Int
    let owner: Owner
    let likes: Likes

    var isFilled: Bool {
        return likes.liked != nil && likes.count != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, owner, likes
    }
}

struct VKFavList: Codable {
    let count: Int
    let items: [Int]

    enum CodingKeys: String, CodingKey {
        case count, items
    }
}

struct VKReposts: Codable {
    let count: Int
}

protocol VKEntityHashable: Hashable {
    var id: Int { get }
    var ownerId: Int { get }
}

extension VKEntityHashable {
    var hashValue: Int {
        return id
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        /* ID VKontakte does not guarantee uniqueness */
        return lhs.id == rhs.id && lhs.ownerId == rhs.ownerId
    }
}

extension VKEntityHashable where Self == VKPhoto {
    var isLocked: Bool {
        return VKApiClient.lockedPhotos.isLocked(self)
    }

    func lock() {
        VKApiClient.lockedPhotos.lock(self)
    }

    func unlock() {
        VKApiClient.lockedPhotos.unlock(self)
    }
}
