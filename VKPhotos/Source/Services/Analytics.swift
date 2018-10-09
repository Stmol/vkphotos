//
//  Analytics.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 22/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

// Firebase Analytics Events
enum AnalyticsEvent {
    // Common
    static let Logout = "logout"
    static let HUDCancelTap = "hud_cancel_tap"
    static let ConnectByWiFi = "connect_wifi" // deprecated
    static let ConnectByCellular = "connect_cellular" // deprecated
    static let RequestReview = "request_review"
    static let ShowAlert = "show_alert"

    // Users
    static let UserBlock = "vk_user_block"
    static let UserUnblock = "vk_user_unblock"

    // Login
    static let TapLoginAppRules = "tap_app_rules"
    static let TapVKRules = "tap_vk_rules"

    // VKontakte
    static let VKNeedCaptcha = "vk_need_captcha"
    static let VKAuthFailed = "vk_auth_failed"
    static let VKTokenExpired = "vk_token_expired"
    static let VKTokenUpdated = "vk_token_updated"
    static let VKAPIRequest = "vk_api_request"

    // Albums
    static let AlbumCreate = "album_create"
    static let AlbumEdit = "album_edit"
    static let AlbumDelete = "album_delete"

    // Photos
    static let PhotoDelete = "photo_delete"
    static let PhotoRestore = "photo_restore"
    static let PhotoCopyToSaves = "photo_copy_to_saves"
    static let PhotoMakeCover = "photo_make_cover"
    static let PhotoMoveToAlbum = "photo_move_to_album"
    static let PhotoEditCaption = "photo_edit_caption"
    static let PhotoLike = "photo_like"
    static let PhotoDislike = "photo_dislike"
    static let PhotoShare = "photo_share"
    static let PhotoAuthorLookup = "photo_author_lookup"
    static let PhotoTextLookup = "photo_text_lookup"
    static let PhotoUploadFromCamera = "photo_upload_from_camera"
    static let PhotoUploadFromLib = "photo_upload_from_lib"
    static let PhotoMultiDelete = "photo_multi_delete"
    static let PhotoMultiMove = "photo_multi_move"
    static let PhotoReport = "photo_report"

    // Photo Uploading
    static let PhotoUploadStart = "photo_upload_start"
    static let PhotoUploadInterrupt = "photo_upload_interrupt"
    static let PhotoUploadError = "photo_upload_error"

    // Settings
    static let ImageCacheClear = "image_cache_clear"
    static let TapVKGroup = "tap_vkgroup_link"
    static let TapVKPrivacyPolicy = "tap_vkpolicy_link"
    static let TapShareAppWithFriends = "tap_share_app_to_friends"
    static let TapRateApp = "tap_rate_app"
    static let TapLicenses = "tap_licenses"
    static let TapAppStoreReview = "tap_app_store_review"
    static let ShareAppLink = "share_app_link"
}
