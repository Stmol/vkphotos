//
// Created by Yury Smidovich on 04/05/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

struct VKPhotoUploadResult: Decodable {
    let albumId: Int
    let server: Int
    let hash: String
    let photosList: String

    enum CodingKeys: String, CodingKey {
        case server, hash
        case albumId = "aid"
        case photosList = "photos_list"
    }
}
