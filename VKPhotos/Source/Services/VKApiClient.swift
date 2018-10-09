//
//  VKApiClient.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import VKSdkFramework
import Hydra
import Alamofire
import Firebase
import Crashlytics

enum VKApiClientErrors: Error {
    case ConnectionError(error: NSError)
    case VKApiError(VKError: VKError)
    case DataFetching
    case RequestCancelled
    case BadRequest
    case Unknown
    case InvalidParams
    case NoInternetConnection
    case ResponseDataUnexpected // Когда данные от АПИ пришли, натянулись на модельку, но как-то криво
    case AuthRequired // Для выполнения запроса требуется авторизация
}

class VKApiClient {
    typealias Errors = VKApiClientErrors

    static var lockedAlbums = LockableEntity<VKAlbum>()
    static var lockedPhotos = LockableEntity<VKPhoto>()

    private let DEFAULT_ATTEMPTS_COUNT: Int32 = 3
    private var userId: String?
    private var isDebug = false

    var token = InvalidationToken()

    init() {
        if
            let accessToken = VKSdk.accessToken(),
            let userId = accessToken.userId {
                self.userId = userId
            }

        #if DEBUG
            self.isDebug = true
        #else
            self.isDebug = false
        #endif
    }
}

// MARK: PHOTOS -
typealias VKPhotosResult = (vkPhotos: [VKPhoto], totalCount: Int)

extension VKApiClient
{
    // photos.getAll
    func fetchAllPhotos(count: Int = 20, offset: Int = 0) -> Promise<VKPhotosResult> {
        let count = count > 200 ? 200 : count // TODO: Log
        let params = [
            "count": String(count),
            "offset": String(offset),
            "extended": "1",
            "photo_sizes": "1"
        ]

        let request = VKRequest(method: "photos.getAll", parameters: params)!
        let promise: Promise<VKResponseCollection<VKPhoto>> = sendRequest(request)

        return Promise<VKPhotosResult>(in: .main) { resolve, reject, _ in
            promise
                .then { resolve(($0.data.items, $0.data.count)) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.getLikedPhotos
    func fetchFavPhotos(count: Int = 20, offset: Int = 0) -> Promise<VKPhotosResult> {
        let params = [
            "photo_sizes": "1",
            "count": String(count),
            "offset": String(offset)
        ]

        let request = VKRequest(method: "execute.getLikedPhotos", parameters: params)!
        let promise: Promise<VKResponseCollection<VKPhoto>> = sendRequest(request)

        return Promise<VKPhotosResult>(in: .main) { resolve, reject, _ in
            promise
                .then { response in
                    resolve((response.data.items, response.data.count))
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // Stored procedure <getPhotosInAlbum>
    func fetchPhotosInAlbum(albumId: Int, count: Int = 20, offset: Int = 0) -> Promise<VKPhotosResult> {
        let params = [
            "album_id": String(albumId),
            "count": String(count),
            "offset": String(offset),
            "rev": "1",
            "extended": "1",
            "photo_sizes": "1"
        ]

        let request = VKRequest(method: "execute.getPhotosInAlbum", parameters: params)!
        let promise: Promise<VKResponseCollection<VKPhoto>> = sendRequest(request)

        return Promise<VKPhotosResult>(in: .main) { resolve, reject, _ in
            promise
                .then { resolve(($0.data.items, $0.data.count)) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.delete
    func photosDelete(id: Int, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let request = VKRequest(method: "photos.delete", parameters: ["photo_id": String(id)])!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { response in
                    if response.data == 1 { resolve(true); return }
                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.restore
    func photosRestore(id: Int, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let request = VKRequest(method: "photos.restore", parameters: ["photo_id": String(id)])!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { response in
                    if response.data == 1 {
                        resolve(true); return
                    }

                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.edit
    func photosEdit(id: Int, caption: String = "", token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }
            let params = [
                "photo_id": String(id),
                "caption": caption
    //            "owner_id": "",
    //            "latitude": 0.0,
    //            "longitude": 0.0,
    //            "place_str": "",
    //            "foursquare_id": "",
    //            "delete_place": "1"
            ]

            let request = VKRequest(method: "photos.edit", parameters: params)!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { response in
                    if response.data == 1 {
                        resolve(true); return
                    }

                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.getUploadServer
    func getUploadServer(albumId: Int) -> Promise<VKPhotoUploadInfo> {
        let request = VKRequest(method: "photos.getUploadServer", parameters: ["album_id": String(albumId)])!
        let promise: Promise<VKResponseData<VKPhotoUploadInfo>> = sendRequest(request)

        return Promise<VKPhotoUploadInfo>(in: .main) { resolve, reject, _ in
            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: photos.save
    func savePhoto(_ vkPhotoUploadResult: VKPhotoUploadResult, caption: String = "") -> Promise<VKPhoto> {
        let params = [
            "album_id": String(vkPhotoUploadResult.albumId),
            "server": String(vkPhotoUploadResult.server),
            "hash": String(vkPhotoUploadResult.hash),
            "photos_list": vkPhotoUploadResult.photosList,
            "caption": caption
        ]

        let request = VKRequest(method: "photos.save", parameters: params)!
        let promise: Promise<VKResponseData<[VKPhoto]>> = sendRequest(request)

        return Promise<VKPhoto>(in: .main) { resolve, reject, _ in
            promise
                .then { resolve($0.data[0]) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    func uploadPhoto(_ image: UIImage, albumId: Int, progress: ((Float) -> Void)?) -> Promise<VKPhoto> {
        return Promise<VKPhoto>(in: .main) { resolve, reject, _ in
            let parameters = VKImageParameters()
            parameters.imageType = VKImageTypeJpg
            parameters.jpegQuality = 1.0

            let request = VKUploadPhotoRequest(image: image, parameters: parameters, albumId: albumId, groupId: 0)!
            let promise: Promise<VKResponseData<[VKPhoto]>> = self.sendRequest(request) { progress?($0) }

            promise
                .then { resolve($0.data[0]) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/likes.add
    func likePhoto(_ vkPhoto: VKPhoto) -> Promise<Int> {
        var params = [
            "type": "photo",
            "item_id": String(vkPhoto.id),
            "owner_id": String(vkPhoto.ownerId)
        ]

        if let accessKey = vkPhoto.accessKey {
            params["access_key"] = accessKey
        }

        let request = VKRequest(method: "likes.add", parameters: params)!
        let promise: Promise<VKResponseData<[String: Int]>> = sendRequest(request)

        return Promise<Int>(in: .main) { resolve, reject, _ in
            promise
                .then { response in
                    if let count = response.data["likes"] {
                        resolve(count); return
                    }

                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/likes.delete
    func dislikePhoto(_ vkPhoto: VKPhoto) -> Promise<Int> {
        let params = [
            "type": "photo",
            "owner_id": String(vkPhoto.ownerId),
            "item_id": String(vkPhoto.id)
        ]

        let request = VKRequest(method: "likes.delete", parameters: params)!
        let promise: Promise<VKResponseData<[String: Int]>> = sendRequest(request)

        return Promise<Int>(in: .main) { resolve, reject, _ in
            promise
                .then { response in
                    if let count = response.data["likes"] {
                        resolve(count); return
                    }

                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.getPhotosInfo
    func getPhotosInfo(_ vkPhotos: [VKPhoto]) -> Promise<[VKPhotoInfo]> {
        return Promise<[VKPhotoInfo]>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let photoIds = vkPhotos.map { vkPhoto -> String in
                var photoId = "\(vkPhoto.ownerId)_\(vkPhoto.id)"
                if let accessKey = vkPhoto.accessKey {
                    photoId += "_\(accessKey)"
                }

                return photoId
            }

            let request = VKRequest(method: "execute.getPhotosInfo", parameters: ["photo_ids": photoIds.joined(separator: ",")])!
            let promise: Promise<VKResponseData<[VKPhotoInfo]>> = this.sendRequest(request)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/likes.getList
    func likesGetList(_ vkPhoto: VKPhoto) -> Promise<VKFavList> {
        return Promise<VKFavList>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }
            let params = [
                "type": "photo",
                "owner_id": "\(vkPhoto.ownerId)",
                "item_id": "\(vkPhoto.id)",
                "filter": "likes",
                "friends_only": "0",
                "extended": "0",
                "offset": "0",
                "count": "1",
                "skip_own": "0"
            ]

            let request = VKRequest(method: "likes.getList", parameters: params)!
            let promise: Promise<VKResponseData<VKFavList>> = this.sendRequest(request)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.copyPhoto - копирует фото в сохраны
    func copyPhoto(_ vkPhoto: VKPhoto, token: InvalidationToken? = nil) -> Promise<VKPhoto> {
        return Promise<VKPhoto>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }
            guard let userId = this.userId else { reject(Errors.AuthRequired); return}

            var params = [
                "user_id": userId,
                "owner_id": String(vkPhoto.ownerId),
                "photo_id": String(vkPhoto.id)
            ]

            if let accessKey = vkPhoto.accessKey {
                params["access_key"] = accessKey
            }

            let request = VKRequest(method: "execute.copyPhoto", parameters: params)!
            let promise: Promise<VKResponseData<VKPhoto>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.movePhoto - переносит фото в другой альбом
    func movePhoto(_ vkPhoto: VKPhoto, to vkAlbum: VKAlbum, token: InvalidationToken? = nil) -> Promise<VKPhoto> {
        return Promise<VKPhoto>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let params = [
                "owner_id": String(vkPhoto.ownerId),
                "photo_id": String(vkPhoto.id),
                "target_album_id": String(vkAlbum.id)
            ]

            let request = VKRequest(method: "execute.movePhoto", parameters: params)!
            let promise: Promise<VKResponseData<VKPhoto>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.makeCover
    func photosMakeCover(_ vkPhoto: VKPhoto, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let params = [
                "owner_id": String(vkPhoto.ownerId),
                "photo_id": String(vkPhoto.id),
                "album_id": String(vkPhoto.albumId)
            ]

            let request = VKRequest(method: "photos.makeCover", parameters: params)!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data == 1) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.photosMultiDelete
    func photosMultiDelete(_ vkPhotos: [VKPhoto], token: InvalidationToken? = nil) -> Promise<[Int]> {
        return Promise<[Int]>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self, !vkPhotos.isEmpty && vkPhotos.count <= 25 else {
                reject(Errors.InvalidParams); return
            }

            let ids = vkPhotos.map({ vkPhoto -> String in return "\(vkPhoto.ownerId)_\(vkPhoto.id)" })
            let request = VKRequest(method: "execute.photosMultiDelete", parameters: ["photo_ids": ids.joined(separator: ",")])!
            let promise: Promise<VKResponseData<[Int]>> = this.sendRequest(request, timeout: 15, token: token) // TODO: На удаление нужно понять какой таймаут

            promise
                .then { resolve($0.data) }
                .cancelled { reject(Errors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.photosMultiMove
    func photosMultiMove(_ vkPhotos: [VKPhoto], to vkAlbum: VKAlbum, token: InvalidationToken? = nil) -> Promise<[Int]> {
        return Promise<[Int]>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self, !vkPhotos.isEmpty && vkPhotos.count <= 25 else {
                reject(Errors.InvalidParams); return
            }

            let ids = vkPhotos.map({ vkPhoto -> String in return "\(vkPhoto.ownerId)_\(vkPhoto.id)" })
            let request = VKRequest(method: "execute.photosMultiMove", parameters: [
                "photo_ids": ids.joined(separator: ","),
                "target_album_id": String(vkAlbum.id)
            ])!
            let promise: Promise<VKResponseData<[Int]>> = this.sendRequest(request, timeout: 15, token: token)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(Errors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.report
    func photosReport(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let params = [
                "owner_id": String(vkPhoto.ownerId),
                "photo_id": String(vkPhoto.id),
                "reason": String(reason.rawValue)
            ]

            let request = VKRequest(method: "photos.report", parameters: params)!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data == 1) }
                .cancelled { reject(Errors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.photoReportAndDislike
    func photoReportAndDislike(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let params = [
                "owner_id": String(vkPhoto.ownerId),
                "photo_id": String(vkPhoto.id),
                "reason": String(reason.rawValue)
            ]

            let request = VKRequest(method: "execute.photoReportAndDislike", parameters: params)!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data == 1) }
                .cancelled { reject(Errors.RequestCancelled) }
                .catch { reject($0) }
        }
    }
}

// MARK: ALBUMS -
extension VKApiClient {
    typealias VKAlbumsResult = (vkAlbums: [VKAlbum], totalCount: Int)

    // API: https://vk.com/dev/photos.createAlbum
    func createAlbum(_ dto: VKAlbumDTO, token: InvalidationToken? = nil) -> Promise<VKAlbum> {
        var params = ["title": dto.title]

        if let description = dto.description {
            params["description"] = description
        }

        if let viewPrivacyValue = dto.viewPrivacy.privacyAccess?.rawValue {
            params["privacy_view"] = viewPrivacyValue
        }

        if let commentPrivacyValue = dto.commentPrivacy.privacyAccess?.rawValue {
            params["privacy_comment"] = commentPrivacyValue
        }

        let request = VKRequest(method: "photos.createAlbum", parameters: params)!
        let promise: Promise<VKResponseData<VKAlbum>> = sendRequest(request, token: token)

        return Promise<VKAlbum>(in: .main) { resolve, reject, _ in
            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: execute.editAlbum
    func editAlbum(_ dto: VKAlbumDTO, token: InvalidationToken? = nil) -> Promise<VKAlbum> {
        return Promise<VKAlbum>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self, let vkAlbum = dto.vkAlbum else {
                reject(VKApiClientErrors.InvalidParams); return
            }

            var params = [
                "album_id": String(vkAlbum.id),
                "owner_id": String(vkAlbum.ownerId),
                "title": dto.title
            ]

            if let description = dto.description {
                params["desc"] = description
            }

            if let viewPrivacyValue = dto.viewPrivacy.privacyAccess?.rawValue {
                params["privacy_view"] = viewPrivacyValue
            }

            if let commentPrivacyValue = dto.commentPrivacy.privacyAccess?.rawValue {
                params["privacy_comment"] = commentPrivacyValue
            }

            let request = VKRequest(method: "execute.editAlbum", parameters: params)!
            let promise: Promise<VKResponseData<VKAlbum>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/photos.deleteAlbum
    func photosDeleteAlbum(_ vkAlbum: VKAlbum, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let request = VKRequest(method: "photos.deleteAlbum", parameters: ["album_id": String(vkAlbum.id)])!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { response in
                    if response.data == 1 { resolve(true); return }
                    reject(VKApiClientErrors.DataFetching)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // Stored procedure <execute.getAlbumsWithTotalCount>
    func fetchAlbumsWithTotalCount(count: Int = 20, offset: Int = 0, isNeedSystem: Bool = true) -> Promise<VKAlbumsResult> {
        let params = [
            "count": String(count),
            "offset": String(offset),
            "need_system": isNeedSystem ? "1" : "0",
            "need_covers": "1",
            "photo_sizes": "1"
        ]

        let request = VKRequest(method: "execute.getAlbumsWithTotalCount", parameters: params)!
        let promise: Promise<VKResponseCollection<VKAlbum>> = sendRequest(request)

        return Promise<VKAlbumsResult>(in: .utility) { resolve, reject, _ in
            promise
                .then { resolve(($0.data.items, $0.data.count)) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // TODO: delete
    func getAlbumsWithTotalCount(count: Int = 20, offset: Int = 0, isNeedSystem: Bool = true) -> Promise<([VKAlbum], Int)> {
        return Promise<([VKAlbum], Int)>(in: .userInitiated) { [weak self] resolve, reject, _ in
            let params = [
                "count": String(count),
                "offset": String(offset),
                "need_system": isNeedSystem ? "1" : "0",
                "need_covers": "1",
                "photo_sizes": "1"
            ]

            guard
                let albumsRequest = VKRequest(method: "photos.getAlbums", parameters: params),
                let albumsCountRequest = VKRequest(method: "photos.getAlbumsCount", parameters: [:])
                else { reject(VKApiClientErrors.BadRequest); return }

            VKBatchRequest(requestsArray: [albumsCountRequest, albumsRequest])
                .execute(
                    resultBlock: { [weak self] responses in

                        guard
                            responses?.count == 2,
                            let totalCountResponse = responses?[0] as? VKResponse,
                            let albumsResponse = responses?[1] as? VKResponse
                            else { reject(VKApiClientErrors.BadRequest); return }

                        if
                            let totalCountData: VKResponseData<Int> = self?.decodeResponse(response: totalCountResponse),
                            let albumsData: VKResponseCollection<VKAlbum> = self?.decodeResponse(response: albumsResponse) {
                            resolve((albumsData.data.items, totalCountData.data))
                        }

                        reject(VKApiClientErrors.DataFetching)
                    },
                    errorBlock: self?.vkErrorBlock(true, errorHandler: reject)
                )
        }
    }
}

// MARK: User -
extension VKApiClient {

    // API: https://vk.com/dev/account.ban
    func accountBan(ownerId: Int, token: InvalidationToken? = nil) -> Promise<Bool> {
        return Promise<Bool> { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let request = VKRequest(method: "account.ban", parameters: ["owner_id": ownerId])!
            let promise: Promise<VKResponseData<Int>> = this.sendRequest(request, token: token)

            promise
                .then { resolve($0.data == 1) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    // API: https://vk.com/dev/account.getBanned
    func accountGetBanned(offset: Int = 0, count: Int = 20, token: InvalidationToken? = nil) -> Promise<([VKBannedUser], Int)> {
        return Promise<([VKBannedUser], Int)> { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            let request = VKRequest(method: "account.getBanned", parameters: ["offset": String(offset), "count": String(count)])!
            let promise: Promise<VKResponseCollection<VKBannedUser>> = this.sendRequest(request, token: token)

            promise
                .then { resolve(($0.data.items, $0.data.count)) }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

}

// MARK: Common -
extension VKApiClient {

    typealias MetaInfo = (albumsCount: Int, photosCount: Int)

    // API: execute.getMetaInfo
    func getMetaInfo() -> Promise<MetaInfo> {
        return Promise<MetaInfo>(in: .main) { [weak self] resolve, reject, _ in
            guard let this = self else { return }
            guard let userId = this.userId else { reject(Errors.AuthRequired); return}

            let request = VKRequest(method: "execute.getMetaInfo", parameters: ["user_id": userId])!
            let promise: Promise<VKResponseData<[String: Int]>> = this.sendRequest(request)

            promise
                .then { response in
                    guard
                        let albumsCount = response.data["albums_count"],
                        let photosCount = response.data["photos_count"]
                        else { reject(VKApiClientErrors.DataFetching); return }

                    let result: MetaInfo = (Int(albumsCount), Int(photosCount))
                    resolve(result)
                }
                .cancelled { reject(VKApiClientErrors.RequestCancelled) }
                .catch { reject($0) }
        }
    }

    private func sendRequest<T: Decodable>(
        _ vkRequest: VKRequest,
        timeout: Int = 10,
        attempts: Int = 1,
        wait: Bool = false,
        token: InvalidationToken? = nil,
        progressBlock: ((Float) -> Void)? = nil
        ) -> Promise<T> {
        return Promise<T>(in: .userInitiated, token: token ?? self.token) { resolve, reject, operation in
            vkRequest.attempts = Int32(attempts)
            vkRequest.waitUntilDone = wait
            vkRequest.requestTimeout = timeout

            // Completion Block
            vkRequest.completeBlock = { response in
                if operation.isCancelled {
                    print("[API] ✋ Cancel in Complete Block: \(vkRequest.methodName!)")
                    vkRequest.cancel()
                    operation.cancel()
                    return
                }

                print("[API] ✅️ \(vkRequest.methodName!)")

                do {
                    let responseString = response!.responseString.data(using: .utf8)
                    let decodedResponse: T = try JSONDecoder().decode(T.self, from: responseString ?? Data())

                    resolve(decodedResponse)
                } catch {
                    print("[API] ⚠️️️️ Decode error: \(vkRequest.methodName!)")
                    print(error.localizedDescription)

                    Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: [
                        "method": vkRequest.methodName
                    ])

                    reject(error)
                }
            }

            // Error Block
            vkRequest.errorBlock = { error in
                if operation.isCancelled {
                    print("[API] ✋ Cancel in Error Block: \(vkRequest.methodName!)")
                    operation.cancel()
                    return
                }

                print("[API] ⛔️️ \(vkRequest.methodName!): \(error!.localizedDescription)")

                guard let error = error as NSError? else {
                    reject(Errors.BadRequest)
                    return
                }

                if error.code != VK_API_ERROR {
                    // TODO: Check repeat mechanism
                    // error.vkError.request.repeat()

                    switch error.code {
                    case -1009: reject(Errors.NoInternetConnection); return
                    default: print("[API] ⚠️ Code: \(error.code)")
                    }
                }

                switch error.vkError.errorCode {
                // https://vk.com/dev/errors
                //
                // 4: Неверная подпись
                // 5: Авторизация пользователя не удалась
                case 4, 5: dispatch(.vkUserLogout, nil)
                default: print("[API] VK Error code: \(error.vkError.errorCode)")
                }

                Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: [
                    "method": vkRequest.methodName,
                    "vk_error_code": error.vkError.errorCode
                ])

                reject(error)
            }

            // Progress block
            vkRequest.progressBlock = { _, loaded, total in
                if operation.isCancelled {
                    print("[API] ✋ Cancel in Progress Block: \(vkRequest.methodName!)")
                    vkRequest.cancel()
                    //operation.cancel()
                    return
                }

                let fractionBytes = Float(loaded) / Float(total)
                progressBlock?(fractionBytes)
            }

            print("[API] ➡️ \(vkRequest.methodName!)")
            vkRequest.start()
            Analytics.logEvent(AnalyticsEvent.VKAPIRequest, parameters: ["method": vkRequest.methodName])
        }
    }

    private func decodeResponse<T: Decodable>(response: VKResponse<VKApiObject>) -> T? {
        do {
            if let responseString = response.responseString.data(using: .utf8) {
                return try JSONDecoder().decode(T.self, from: responseString)
            }

            throw VKApiClientErrors.DataFetching
        } catch {
            logError(error.localizedDescription)
            return nil
        }
    }

    private func vkErrorBlock(
            _ isRepeating: Bool = true,
            errorHandler: @escaping (VKApiClientErrors) -> Void
    ) -> (Error?) -> Void {
        return { [weak self] error in
            guard let error = error as NSError? else {
                self?.logError("Error is undefined in error block!")
                return
            }

            if error.code != VK_API_ERROR {
                if isRepeating {
                    error.vkError.request.repeat()
                }

                errorHandler(.ConnectionError(error: error))
                return
            }

            if let vkError = error.vkError {
                self?.logError("Code: \(vkError.errorCode) | Message: \(String(describing: vkError.errorMessage))")

                switch vkError.errorCode {
                case 5: print(">> LOGOUT <<")
                default: errorHandler(.VKApiError(VKError: error.vkError)); return
                }
            }

            self?.logError("All goes down")
            errorHandler(.Unknown)
        }
    }

    private func logError(_ message: String) {
        if isDebug { print("[API ERROR] \(message)") }
    }

    private func logInfo(_ message: String) {
        if isDebug { print("[API] \(message)") }
    }

}
