//
//  VKPhotoUploadServer.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 29/04/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

struct VKPhotoUploadInfo: Decodable {
    let uploadUrl: String
    let albumId: Int
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case albumId = "album_id"
        case userId = "user_id"
    }
}
