//
//  VKBannedUser.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 23/09/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

struct VKBannedUser: Codable {

    let id: Int
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
    }

}
