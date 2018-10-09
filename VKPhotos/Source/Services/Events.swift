//
//  Events.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 30/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Foundation

extension Notification.Name {

    // Photos Events
    static let vkPhotosDeleted = Notification.Name("vk_photos.deleted")
    static let vkPhotosMoved = Notification.Name("vk_photos.moved")
    static let vkPhotosRestored = Notification.Name("vk_photos.restored")
    static let vkPhotosUploaded = Notification.Name("vk_photos.uploaded")
    static let vkPhotosInfoUpdated = Notification.Name("vk_photos.info_updated")
    static let vkPhotosCopied = Notification.Name("vk_photos.copy")
    static let vkPhotosFetched = Notification.Name("vk_photos.fetched")

    static let vkPhotoCaptionEdited = Notification.Name("vk_photo.caption_edited")
    static let vkPhotoMoved = Notification.Name("vk_photo.moved")
    static let vkPhotoLiked = Notification.Name("vk_photo.liked")
    static let vkPhotoDisliked = Notification.Name("vk_photo.disliked")
    static let vkPhotoMakeCover = Notification.Name("vk_photo.make_cover")
    static let vkPhotoReported = Notification.Name("vk_photo.reported")

    static let photosManagerStateUpdated = Notification.Name("photos_manager.state.updated")

    // Albums Events
    static let vkAlbumsDeleted = Notification.Name("vk_albums.deleted")
    static let vkAlbumCreated = Notification.Name("vk_album.created")
    static let vkAlbumEdited = Notification.Name("vk_album.edited")

    // User Events
    static let vkUserLogout = Notification.Name("vk_user.logout")
    static let vkUserBlocked = Notification.Name("vk_user.blocked")
    static let vkUserUnblocked = Notification.Name("vk_user.unblocked")
}

protocol VKPhotosEvent {
    var vkPhotos: [VKPhoto] { get }
}

struct VKPhotosDeletedEvent: VKPhotosEvent {
    let vkPhotos: [VKPhoto]
}

struct VKPhotosMovedEvent: VKPhotosEvent {
    let vkPhotos: [VKPhoto]
    let fromVKAlbum: VKAlbum
    let targetVKAlbum: VKAlbum
}

struct VKPhotoMovedEvent {
    let vkPhoto: VKPhoto
    let fromVKAlbumID: Int
    //let fromVKAlbum: VKAlbum TODO: Здесь как-то нужно передавать сущность альбома, а не просто ID
    let targetVKAlbum: VKAlbum
}

struct VKPhotosRestoredEvent: VKPhotosEvent {
    let vkPhotos: [VKPhoto]
}

struct VKPhotosUploadedEvent: VKPhotosEvent {
    let vkPhotos: [VKPhoto]
    let targetVKAlbum: VKAlbum
}

struct VKPhotoDislikedEvent {
    let vkPhoto: VKPhoto
    let likesCount: Int
}

struct VKPhotoLikedEvent {
    let vkPhoto: VKPhoto
    let likesCount: Int
}

struct VKPhotosInfoUpdatedEvent: VKPhotosEvent {
    let vkPhotos: [VKPhoto] // TODO: неправильно, как соотнести массив фото и инфы?
    let vkPhotosInfo: [VKPhotoInfo]
}

struct VKPhotoCopiedEvent {
    let vkPhoto: VKPhoto
}

struct VKPhotoCaptionEditedEvent {
    let vkPhoto: VKPhoto
    let caption: String
}

struct VKPhotoMakeCoverEvent {
    let vkPhoto: VKPhoto
}

struct VKPhotoReportedEvent {
    let vkPhoto: VKPhoto
}

struct VKPhotosFetchedEvent {
    let vkPhotos: [VKPhoto]
    let totalCount: Int
    let inVKAlbum: VKAlbum?
}

// MARK: Albums -
struct VKAlbumsDeletedEvent {
    let vkAlbums: [VKAlbum]
}

struct VKAlbumCreatedEvent {
    let vkAlbum: VKAlbum
}

struct VKAlbumEditedEvent {
    let vkAlbum: VKAlbum
}

// MARK: Users -
struct VKUserBlockedEvent {
    let id: Int // VK User or VK Group ID
}

struct VKUserUnblockedEvent {
    let id: Int // VK User or VK Group ID
}
