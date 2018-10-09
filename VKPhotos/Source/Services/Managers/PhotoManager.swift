//
// Created by Yury Smidovich on 13/03/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import UIKit
import Hydra

// TODO: Где должны быть все эти общие типы?
typealias ActionResult = (isSuccess: Bool, isCancel: Bool)

// TODO: Переименовать и унести в места общего сосредоточения
enum OperationError: Error {
    case failed
    case cancelled
    case dataInconsistency
    case noConnection

    static func fromError(_ error: Error) -> OperationError {
        if let error = error as? VKApiClientErrors {
            switch error {
            case .RequestCancelled: return .cancelled
            case .NoInternetConnection: return .noConnection
            default: return .failed
            }
        }

        if let error = error as? APIOperationError {
            switch error {
            case .cancelled: return .cancelled
            default: return .failed
            }
        }

        return .failed
    }
}

enum OperationResult<T> {
    case success(T)
    case failure(OperationError)
}

protocol PhotoManager: class {
    typealias VKPhotosState = (vkPhotos: [VKPhoto], totalCount: Int)

    // MARK: Outputs
    var vkPhotos: [VKPhoto] { get }
    var totalCount: Int { get }
    var name: VKPhotoManager.Name { get }

    var onVKPhotosUpdate: (([VKPhoto]) -> Void)? { get set }
    var onTotalCountUpdate: ((Int) -> Void)? { get set }

    // MARK: Actions
    func getPhotos(count: Int, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void)
    func getNextPhotos(count: Int, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void)
    func syncStateWithServer(_ completion: @escaping (OperationResult<[VKPhoto]>) -> Void)

    func movePhoto(_ vkPhoto: VKPhoto, _ toVKAlbum: VKAlbum, _ completion: @escaping (OperationResult<VKPhoto>) -> Void) -> VKPhotoMoveOperation?
    func copyPhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<VKPhoto>) -> Void) -> VKPhotoCopyOperation?
    func editPhotoCaption(_ vkPhoto: VKPhoto, caption: String, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoEditCaptionOperation?
    func deletePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoDeleteOperation?
    func restorePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoRestoreOperation?
    func likePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Int>) -> Void)
    func dislikePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Int>) -> Void)
    func makeCover(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoMakeCoverOperation?
    func reportAndDislike(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoReportAndDislikeOperation?

    func updatePhotosInfo(_ vkPhotos: [VKPhoto], _ completion: @escaping (OperationResult<[VKPhotoInfo]>) -> Void)
    func multiDelete(_ vkPhotos: [VKPhoto], _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) -> VKPhotosMultiDeleteOperation?
    func multiMove(_ vkPhotos: [VKPhoto], _ toVKAlbum: VKAlbum, _ fromVKAlbum: VKAlbum, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) -> VKPhotosMultiMoveOperation?

    func cleanupState(_ completion: ((Bool) -> Void)?)
}

protocol VKAPIManager: class {
    func cancelAllRequests(then: (() -> Void)?)
}

class VKPhotoManager: PhotoManager, VKAPIManager {
    enum Name {
        case all, fav, album
    }

    deinit {
        api.token.invalidate()
        // VKApiClient.lockedPhotos.free() TODO check
    }

    fileprivate let photosQueue = DispatchQueue(label: "io.vk_photo_manager.photos", attributes: .concurrent)
    fileprivate let apiOperations: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "io.vk_photo_manager.api_operations"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    fileprivate var offset: Int {
        // Это шляпа :( но что поделать если придумал галерею, которая содержит в себе удаленные фотки
        return vkPhotos.filter({ !$0.isDeleted }).count
    }
    fileprivate var state = VKPhotosState([], 0) {
        didSet {
            guard oldValue.totalCount == state.totalCount else { return }
            DispatchQueue.main.async { [weak self] in
                guard let totalCount = self?.state.totalCount else { return }
                self?.onTotalCountUpdate?(totalCount)
            }
        }
    }

    var vkPhotos: [VKPhoto] {
        var result = [VKPhoto]()
        photosQueue.sync { result = state.vkPhotos }
        return result
    }
    var totalCount: Int {
        return state.totalCount // TODO!!! CHECK
//        return state.totalCount - state.vkPhotos.filter({ $0.isDeleted }).count
    }

    var name: Name { return .all }
    var onVKPhotosUpdate: (([VKPhoto]) -> Void)?
    var onTotalCountUpdate: ((Int) -> Void)?

    // Internal
    fileprivate let api = VKApiClient()
    fileprivate var providerKey: String

    fileprivate var loadRequestState: RequestState = .done
    fileprivate var loadNextRequestState: RequestState = .done

    fileprivate var isPhotosAdded = false

    // MARK: Methods -
    init(key: String) {
        self.providerKey = key
        subscribe()
    }

    @objc func onVKPhotosInfoUpdated(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosInfoUpdatedEvent,
            !event.vkPhotosInfo.isEmpty
            else { return }

        var updatedPhotos = [VKPhoto]()
        event.vkPhotosInfo.forEach { vkPhotoInfo in
            guard
                vkPhotoInfo.isFilled,
                let index = self.state.vkPhotos.index(where: {
                    $0.id == vkPhotoInfo.id && $0.ownerId == vkPhotoInfo.owner.id
                }) else { return }

            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos[index].updateInfo(vkPhotoInfo)
            }
            updatedPhotos.append(vkPhotos[index])
        }

        if updatedPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.onVKPhotosUpdate?(updatedPhotos)
        }
    }

    @objc func onVKPhotosRestored(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosRestoredEvent,
            !event.vkPhotos.isEmpty
            else { return }

        var restoredPhotos = [VKPhoto]()
        event.vkPhotos.forEach { restoredVKPhoto in
            guard let index = vkPhotos.index(where: { $0 == restoredVKPhoto && $0.isDeleted }) else { return }
            state.totalCount += 1

            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos[index].isDeleted = false
            }

            restoredPhotos.append(vkPhotos[index])
        }

        if restoredPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.onVKPhotosUpdate?(restoredPhotos)
        }
    }

    @objc func onVKPhotosDeleted(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosDeletedEvent,
            !event.vkPhotos.isEmpty
            else { return }

        var deletedPhotos = [VKPhoto]()
        event.vkPhotos.forEach { deletedVKPhoto in
            guard let index = vkPhotos.index(where: { $0 == deletedVKPhoto && !$0.isDeleted }) else { return }
            state.totalCount -= 1

            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos[index].isDeleted = true
            }

            deletedPhotos.append(vkPhotos[index])
        }

        if deletedPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.onVKPhotosUpdate?(deletedPhotos)
        }
    }

    @objc func onVKPhotosMoved(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosMovedEvent, !event.vkPhotos.isEmpty
            else { return }

        var updatedVKPhotos = [VKPhoto]() // TODO: Может тут Set?
        event.vkPhotos.forEach { vkPhoto in
            if let index = vkPhotos.index(of: vkPhoto) {
                photosQueue.async(flags: .barrier) { [unowned self] in
                    self.state.vkPhotos[index].albumId = event.targetVKAlbum.id
                }
                updatedVKPhotos.append(vkPhotos[index])
            } else if event.fromVKAlbum.isSystem, let index = vkPhotos.index(where: { $0.id < vkPhoto.id }) {
                state.totalCount += 1
                isPhotosAdded = true

                photosQueue.async(flags: .barrier) { [unowned self] in
                    self.state.vkPhotos.insert(vkPhoto, at: index)
                }
                updatedVKPhotos.append(vkPhotos[index])
            }
        }

        if updatedVKPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.onVKPhotosUpdate?(updatedVKPhotos)
        }
    }

    @objc func onVKPhotosUploaded(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosUploadedEvent,
            !event.vkPhotos.isEmpty
            else { return }

        let newPhotos = event.vkPhotos.sorted(by: { $0.id > $1.id })

        state.totalCount += event.vkPhotos.count
        isPhotosAdded = true

        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos = newPhotos + self.state.vkPhotos

            DispatchQueue.main.async { [weak self] in
                self?.onVKPhotosUpdate?(newPhotos)
            }
        }
    }

    @objc func onVKPhotoCaptionEdited(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoCaptionEditedEvent,
            let index = vkPhotos.index(of: event.vkPhoto)
            else { return }

        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos[index].text = event.caption

            DispatchQueue.main.async { [weak self] in
                guard let this = self else { return }
                this.onVKPhotosUpdate?([this.vkPhotos[index]])
            }
        }
    }

    @objc func onVKPhotoLiked(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoLikedEvent,
            let index = self.state.vkPhotos.index(of: event.vkPhoto)
            else { return }

        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos[index].like(event.likesCount)

            DispatchQueue.main.async { [weak self] in
                guard let vkPhoto = self?.vkPhotos[index], vkPhoto.isLiked else { return }
                self?.onVKPhotosUpdate?([vkPhoto])
            }
        }
    }

    @objc func onVKPhotoDisliked(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoDislikedEvent,
            let index = vkPhotos.index(of: event.vkPhoto)
            else { return }

        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos[index].dislike(event.likesCount)

            DispatchQueue.main.async { [weak self] in
                guard let vkPhoto = self?.vkPhotos[index], !vkPhoto.isLiked else { return }
                self?.onVKPhotosUpdate?([vkPhoto])
            }
        }
    }

    @objc func onVKPhotoMoved(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoMovedEvent else { return }

        // Фотку перенесли, а значит надо обновить инфу о ней
        if let index = vkPhotos.index(of: event.vkPhoto) {
            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos[index].albumId = event.vkPhoto.albumId

                DispatchQueue.main.async { [weak self] in
                    guard let this = self, index < this.vkPhotos.count else { return }
                    this.onVKPhotosUpdate?([this.vkPhotos[index]])
                }
            }
        // Фотку перенесли из системного альбома - надо добавить ее в общий стек
        // TODO: Это очень стремная логика завязанная на ID альбома, а должна на `isSystem`
        } else if event.fromVKAlbumID < 0, let index = vkPhotos.index(where: { $0.id < event.vkPhoto.id }) {
            state.totalCount += 1
            isPhotosAdded = true

            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos.insert(event.vkPhoto, at: index)

                DispatchQueue.main.async { [weak self] in
                    guard let vkPhoto = self?.vkPhotos[index] else { return }
                    self?.onVKPhotosUpdate?([vkPhoto])
                }
            }
        }
    }

    @objc func onVKPhotoReported(_ notification: NSNotification) {
    }

    @objc func onVKAlbumsDeleted(_ notification: NSNotification) {
        guard let event = notification.object as? VKAlbumsDeletedEvent else { return }

        let deletedAlbumsID = event.vkAlbums.map({ vkAlbum -> Int in return vkAlbum.id })
        let deletedPhotos = vkPhotos.filter({ deletedAlbumsID.contains($0.albumId) })
        guard deletedPhotos.count > 0 else { return }

        state.totalCount -= vkPhotos.count - deletedPhotos.count
        photosQueue.async(flags: .barrier) { [weak self] in
            self?.state.vkPhotos = self?.state.vkPhotos.filter({ !deletedPhotos.contains($0) }) ?? []

            DispatchQueue.main.async { [weak self] in
                self?.onVKPhotosUpdate?(deletedPhotos)
            }
        }
    }

    /// Чистит стейт от того, чего там быть не должно.
    /// Основная идея: привести стейт в идентичное состояние как на сервере
    func cleanupState(_ completion: ((Bool) -> Void)? = nil) {
        guard !vkPhotos.isEmpty else { return }

        let newVKPhotos = vkPhotos.filter({ !$0.isDeleted })
        if newVKPhotos.count == vkPhotos.count {
            completion?(isPhotosAdded); return
        }

        photosQueue.async(flags: .barrier) {
            self.state.vkPhotos = newVKPhotos

            DispatchQueue.main.async {
                completion?(true)
            }
        }
    }

    func cancelAllRequests(then: (() -> Void)? = nil) {
        apiOperations.cancelAllOperations()

        api.token.invalidate() // TODO Еще не все запросы на операциях, поэтому надо отменять их через глобальный токен
        api.token = InvalidationToken()

        loadRequestState = .done
        loadNextRequestState = .done

        then?() // TODO: Мне кажется тут все синхронно выполнится
    }

    // MARK: API Calls -
    func getPhotos(count: Int, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) {
        if loadRequestState == .execute { completion(.failure(.failed)); return }
        loadRequestState = .execute

        fetchVKPhotos(count: count)
            .then { [weak self] vkPhotos, totalCount in
                guard let this = self else {
                    completion(.failure(.failed)); return
                }

                this.state.totalCount = totalCount
                this.photosQueue.async(flags: .barrier) {
                    this.state.vkPhotos = vkPhotos

                    DispatchQueue.main.async {
                        completion(.success(vkPhotos))
                    }
                }

                this.loadRequestState = .done
            }
            .catch { [weak self] error in
                self?.loadRequestState = .done
                completion(.failure(.fromError(error)))
            }
    }

    func getNextPhotos(count: Int, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) {
        if loadNextRequestState == .execute { completion(.failure(.failed)); return }
        loadNextRequestState = .execute

        fetchVKPhotos(count: count, offset: offset)
            .then { [weak self] vkPhotos, totalCount in
                guard let this = self else { completion(.failure(.failed)); return }

                if totalCount < this.state.totalCount {
                    /* 1) На сервере были добавлены новые фотографии
                       2) На сервере были удалены фотографии */
                    completion(.failure(.dataInconsistency))
                    return
                }

                // На сервере были ДОБАВЛЕНЫ фотографии
                if totalCount > this.state.totalCount {
                    let diffCount = totalCount - this.state.totalCount
                    let slicedVKPhotos = Array(vkPhotos.dropFirst(diffCount))

                    let uniqueNewPhotos = slicedVKPhotos.unique(by: this.vkPhotos)
                    if uniqueNewPhotos.isEmpty {
                        completion(.failure(.dataInconsistency))
                        return
                    }

                    this.state.totalCount = totalCount
                    this.photosQueue.async(flags: .barrier) {
                        this.state.vkPhotos += uniqueNewPhotos

                        DispatchQueue.main.async {
                            completion(.success(uniqueNewPhotos))
                        }
                    }

                    return
                }

                let nextVKPhotos = vkPhotos.unique(by: this.vkPhotos)
                if totalCount == this.state.totalCount && !vkPhotos.isEmpty && nextVKPhotos.isEmpty {
                    completion(.failure(.dataInconsistency))
                    return
                }

                this.state.totalCount = totalCount
                this.photosQueue.async(flags: .barrier) {
                    this.state.vkPhotos += nextVKPhotos

                    DispatchQueue.main.async {
                        completion(.success(nextVKPhotos))
                    }
                }

                this.loadNextRequestState = .done
            }
            .catch { [weak self] error in
                self?.loadNextRequestState = .done
                completion(.failure(.fromError(error)))
            }
    }

    func syncStateWithServer(_ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) {
        let operation = VKPhotosSyncOperation(api, vkPhotos.count, 200) { [unowned self] count, offset in
            return self.fetchVKPhotos(count: count, offset: offset)
        }

        operation.completionBlock = { [weak self] in
            if let error = operation.error {
                completion(.failure(.fromError(error)))
                return
            }

            guard let result = operation.result else {
                completion(.failure(.failed))
                return
            }

            // TODO: Это все таки должно быть в реакции на эвент
            self?.state.totalCount = result.totalCount
            self?.photosQueue.async(flags: .barrier) { [weak self] in
                self?.state.vkPhotos = result.vkPhotos

                DispatchQueue.main.async {
                    completion(.success(result.vkPhotos))
                }
            }
        }

        apiOperations.addOperation(operation)
    }

    func editPhotoCaption(_ vkPhoto: VKPhoto, caption: String, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoEditCaptionOperation? {
        guard
            vkPhotos.first(where: { $0 == vkPhoto }) != nil
            else { completion(.failure(.failed)); return nil }

        let operation = VKPhotoEditCaptionOperation(api, vkPhoto, caption)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func deletePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoDeleteOperation? {
        guard
            let vkPhotoToDelete = vkPhotos.first(where: { $0 == vkPhoto }),
            vkPhotoToDelete.isDeleted == false && vkPhotoToDelete.isLocked == false
            else {
            completion(.failure(.failed))
            return nil
        }

        // TODO: Нужно ли выбрасывать типы ошибок и reject?
        //if vkPhoto.isDeleted { completion(.fail(PhotosError.photoAlreadyDeleted)); return }
        //if vkPhoto.isLocked { completion(.fail(PhotosError.photoIsBusy)); return }

        let operation = VKPhotoDeleteOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion) {
            vkPhotoToDelete.unlock()
        }

        vkPhotoToDelete.lock()
        apiOperations.addOperation(operation)

        return operation
    }

    func restorePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoRestoreOperation? {
        guard
            let vkPhotoWillRestore = vkPhotos.first(where: { $0 == vkPhoto }),
            vkPhotoWillRestore.isDeleted == true && vkPhotoWillRestore.isLocked == false
        else {
            completion(.failure(.failed))
            return nil
        }

        //if !vkPhoto.isDeleted { completion(.fail(PhotosError.photoIsNotDeleted)); return }
        //if vkPhoto.isLocked { completion(.fail(PhotosError.photoIsBusy)); return }

        let operation = VKPhotoRestoreOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion) {
            vkPhotoWillRestore.unlock()
        }

        vkPhotoWillRestore.lock()
        apiOperations.addOperation(operation)

        return operation
    }

    func likePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Int>) -> Void) {
        //guard
            // TODO Думаю что не нужна проверка, так как в стейте может быть устаревшая инфа
            //vkPhotos.first(where: { $0 == vkPhoto && $0.isLiked }) == nil
            //else { completion(.failure(.failed)); return }

        if
            // TODO!! опасное место! по сути может получиться так, что на сервере фотка не лайкнута
            // TODO!! и мы говорим: лайкни эту фотку, а менеджер смотрит ее локальное состояние и
            // TODO!! отвечает - ок, она уже лайкнута, все получилось. Хотя это может не совпадать с сервером
            let likedPhoto = vkPhotos.first(where: { $0 == vkPhoto && $0.isLiked }) {
                completion(.success(likedPhoto.likes?.count ?? 1))
                return
            }

        let operation = VKPhotoLikeOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion)

        apiOperations.addOperation(operation)
    }

    func dislikePhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Int>) -> Void) {
        if
            // TODO UPD: Читай туду из метода likePhoto
            let dislikedPhoto = vkPhotos.first(where: { $0 == vkPhoto && !$0.isLiked }) {
                completion(.success(dislikedPhoto.likes?.count ?? 0))
                return
            }

        let operation = VKPhotoDislikeOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion)

        apiOperations.addOperation(operation)
    }

    func updatePhotosInfo(_ vkPhotosToUpdate: [VKPhoto], _ completion: @escaping (OperationResult<[VKPhotoInfo]>) -> Void) {
        let operation = VKPhotosUpdateInfoOperation(api, vkPhotosToUpdate)
        operation.completionBlock = operationCompletion(operation, completion)

        apiOperations.addOperation(operation)
    }

    func copyPhoto(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<VKPhoto>) -> Void) -> VKPhotoCopyOperation? {
        let operation = VKPhotoCopyOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func movePhoto(_ vkPhoto: VKPhoto, _ targetVKAlbum: VKAlbum, _ completion: @escaping (OperationResult<VKPhoto>) -> Void) -> VKPhotoMoveOperation? {
        guard vkPhoto.albumId != targetVKAlbum.id  else { completion(.failure(.failed)); return nil }

        // TODO: Стоит лочить фотку перед мувом?
        let operation = VKPhotoMoveOperation(api, vkPhoto, targetVKAlbum)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func makeCover(_ vkPhoto: VKPhoto, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoMakeCoverOperation? {
        let operation = VKPhotoMakeCoverOperation(api, vkPhoto)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func multiDelete(_ photosToDelete: [VKPhoto], _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) -> VKPhotosMultiDeleteOperation? {
        let operation = VKPhotosMultiDeleteOperation(api, photosToDelete)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    // TODO: По идее перемещение может реализовывать только альбомный менеджер фоток
    func multiMove(_ vkPhotosToMove: [VKPhoto], _ toVKAlbum: VKAlbum, _ fromVKAlbum: VKAlbum, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) -> VKPhotosMultiMoveOperation? {
        let operation = VKPhotosMultiMoveOperation(api, vkPhotosToMove, toVKAlbum, fromVKAlbum)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func reportAndDislike(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKPhotoReportAndDislikeOperation? {
        let operation = VKPhotoReportAndDislikeOperation(api, vkPhoto, reason)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    // MARK: Private -
    fileprivate func fetchVKPhotos(count: Int, offset: Int = 0) -> Promise<VKPhotosResult> {
        return api.fetchAllPhotos(count: count, offset: offset)
    }

    fileprivate func subscribe() {
        startListen(.vkPhotosDeleted, self, #selector(onVKPhotosDeleted))
        startListen(.vkPhotosRestored, self, #selector(onVKPhotosRestored))
        startListen(.vkPhotosInfoUpdated, self, #selector(onVKPhotosInfoUpdated))
        startListen(.vkPhotosUploaded, self, #selector(onVKPhotosUploaded))
        startListen(.vkPhotoCaptionEdited, self, #selector(onVKPhotoCaptionEdited))
        startListen(.vkPhotoLiked, self, #selector(onVKPhotoLiked))
        startListen(.vkPhotoDisliked, self, #selector(onVKPhotoDisliked))
        startListen(.vkAlbumsDeleted, self, #selector(onVKAlbumsDeleted))
        startListen(.vkPhotoMoved, self, #selector(onVKPhotoMoved))
        startListen(.vkPhotosMoved, self, #selector(onVKPhotosMoved))
        startListen(.vkPhotoReported, self, #selector(onVKPhotoReported))
    }

    fileprivate func operationCompletion<T>(
        _ operation: APIOperation<T>,
        _ completion: @escaping ((OperationResult<T>) -> Void),
        _ additional: (() -> Void)? = nil
    ) -> () -> Void {
        return {
            additional?()

            if let result = operation.result {
                DispatchQueue.main.async {
                    completion(.success(result))
                }

                return
            }

            if let error = operation.error {
                DispatchQueue.main.async {
                    completion(.failure(OperationError.fromError(error)))
                }

                return
            }

            DispatchQueue.main.async {
                completion(.failure(.failed))
            }
        }
    }
}

// MARK: Favs -
class VKFavPhotoManager: VKPhotoManager {
    override var name: Name { return .fav }

    override var offset: Int {
        return vkPhotos.filter({
            // !$0.isDeleted && ($0.isLiked || ($0.isFav != nil && $0.isFav == true))
            // TODO: Это сложно объяснить, но это работает. Копать надо в сторону тотал каунта у faves
            !$0.isDeleted && $0.isFav == true
        }).count
    }

    fileprivate var likedPhotos = [VKPhoto]()

    override func onVKPhotoReported(_ notification: NSNotification) {
        /*
        Итак. Привет. Что тут происходит?
        По порядку:
        - Эпл требует скрывать контент с экрана после репорта
        - ВК никак не реагирует на отправку репорта, то есть фотка остается в закладках (ну еще бы)
        - А это значит, что надо накостылять "удаление фотки" путем дизлайка после успешного репорта
        - Достигается это путем вызова кастомного метода одновременно ставящего репорт и удаляющего из избранного
        */

        guard
            let event = notification.object as? VKPhotoReportedEvent,
            let index = vkPhotos.index(of: event.vkPhoto)
            else { return }

        state.totalCount -= 1
        photosQueue.async(flags: .barrier) { [unowned self] in
            let vkPhoto = self.state.vkPhotos.remove(at: index)

            DispatchQueue.main.async { [weak self] in
                self?.onVKPhotosUpdate?([vkPhoto])
            }
        }
    }

    override func onVKPhotosUploaded(_ notification: NSNotification) {}

    override func onVKPhotoLiked(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoLikedEvent else { return }

        var vkPhoto = event.vkPhoto
        vkPhoto.like(event.likesCount) // TODO: Это точно не должно быть в операции?

        likedPhotos = likedPhotos.filter({ $0 != vkPhoto })
        likedPhotos.insert(vkPhoto, at: 0)

        // TODO: Вот сюда сразу смотри - жуть стремное местечко
        if let index = vkPhotos.index(of: vkPhoto) {
            photosQueue.async(flags: .barrier) { [weak self] in
                self?.state.vkPhotos[index].like(event.likesCount)

                DispatchQueue.main.async { [weak self] in
                    self?.onVKPhotosUpdate?([vkPhoto])
                }
            }
        } else {
            onVKPhotosUpdate?([vkPhoto])
        }
    }

    override func onVKPhotosDeleted(_ notification: NSNotification) {
        super.onVKPhotosDeleted(notification)
        guard let event = notification.object as? VKPhotosDeletedEvent else { return }

        likedPhotos = likedPhotos.filter({ !event.vkPhotos.contains($0) })
    }

    override func onVKPhotoDisliked(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoDislikedEvent else { return }

        likedPhotos.removeAll(where: { $0 == event.vkPhoto })
        super.onVKPhotoDisliked(notification)
    }

    override func onVKPhotoMoved(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoMovedEvent,
            let index = vkPhotos.index(of: event.vkPhoto)
            else { return }

        // Фотку перенесли, а значит надо обновить инфу о ней
        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos[index].albumId = event.vkPhoto.albumId

            DispatchQueue.main.async { [weak self] in
                guard let vkPhoto = self?.vkPhotos[index] else { return }
                self?.onVKPhotosUpdate?([vkPhoto])
            }
        }
    }

    override func onVKPhotosMoved(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosMovedEvent,
            !event.vkPhotos.isEmpty
            else { return }

        var updatedVKPhotos = [VKPhoto]()
        event.vkPhotos.forEach { vkPhoto in
            guard let index = vkPhotos.index(of: vkPhoto) else { return }
            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos[index].albumId = event.targetVKAlbum.id
            }
            updatedVKPhotos.append(vkPhotos[index])
        }

        if updatedVKPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
           self?.onVKPhotosUpdate?(updatedVKPhotos)
        }
    }

    override func getNextPhotos(count: Int, _ completion: @escaping (OperationResult<[VKPhoto]>) -> Void) {
        // TODO!!! У раздела избранного в ВК полная вакханалия - полагаться на тотал каунт там нельзя
        // TODO!!! Каждый раз он приходит разный и независимо лайкнул ты что-то или дизлайкнул
        // TODO!!! К тому же он обновляется очень медленно, может до нескольких дней
        // TODO!!! Поэтому в офсете учавствуют только фотки приехавшие с сервера с пометкой isFav
        // ... так же есть тема с доступом: в тотал каунте могут быть учтены фотки, к которым уже нет доступа (или наоборот)
        if loadNextRequestState == .execute { completion(.failure(.failed)); return }
        loadNextRequestState = .execute

        // При запросах к избранным фото нельзя полагаться на тотал каунт
        // поэтому убираем все проверки на ТК...
        fetchVKPhotos(count: count, offset: offset)
            .then { [weak self] vkPhotos, totalCount in
                guard let this = self else { completion(.failure(.failed)); return }

                // ... и просто чистим от повторок
                let nextVKPhotos = vkPhotos.unique(by: this.vkPhotos)

                // доверяемся серверу. TODO: Поискать варианты понадежней
                this.state.totalCount = totalCount
                this.photosQueue.async(flags: .barrier) {
                    this.state.vkPhotos += nextVKPhotos
                }

                this.loadNextRequestState = .done
                completion(.success(nextVKPhotos))
            }
            .catch { [weak self] error in
                self?.loadNextRequestState = .done
                completion(.failure(.fromError(error)))
            }
    }

    override func cleanupState(_ completion: ((Bool) -> Void)? = nil) {
        if vkPhotos.isEmpty && likedPhotos.isEmpty { completion?(false); return }
        print("🛁 Cleanup FAVS")

        /**
         План действий для очистки стейта избранного:
         1. Удалить все удаленные фотки `isDeleted == true`
         2. Удалить все фотки без лайков `isLiked == false`
         3. Добавить в начало лайкнутые фотки из набора `likedPhotos`
        */
        let cleanPhotos = likedPhotos + vkPhotos.filter({
            // TODO: (($0.isFav && ($0.likes == nil || $0.isLiked)) || $0.isLiked) ->
            // TODO: Этот адок, потому то апи избранного не возвращает `likes`
            // TODO: но возвращает `isFav = true` (по моему допилу)
            !$0.isDeleted && (($0.isFav && ($0.likes == nil || $0.isLiked)) || $0.isLiked) && !likedPhotos.contains($0)
        })

        likedPhotos.removeAll()
        if cleanPhotos.count == vkPhotos.count {
            completion?(false); return
        }

        photosQueue.async(flags: .barrier) { [weak self] in
            self?.state.vkPhotos = cleanPhotos

            DispatchQueue.main.async {
                completion?(true)
            }
        }
    }

    fileprivate override func fetchVKPhotos(count: Int, offset: Int) -> Promise<VKPhotosResult> {
        return api.fetchFavPhotos(count: count, offset: offset)
    }
}

// MARK: In Album -
class VKPhotoInAlbumManager: VKPhotoManager {
    override var name: Name { return Name.album }
    private var vkAlbum: VKAlbum

    init(key: String, vkAlbum: VKAlbum) {
        self.vkAlbum = vkAlbum
        super.init(key: key)
    }

    @objc func onVKPhotoCopied(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoCopiedEvent,
            vkAlbum.isAlbumSaved // Только альбом с сохраненками реагирует на происходящее
            else { return }

        state.totalCount += 1
        isPhotosAdded = true

        photosQueue.async(flags: .barrier) { [unowned self] in
            self.state.vkPhotos.insert(event.vkPhoto, at: 0)

            DispatchQueue.main.async { [weak self] in
                self?.onVKPhotosUpdate?([event.vkPhoto])
            }
        }
    }

    override func onVKPhotoMoved(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoMovedEvent else { return }

        // 1. Если это альбом ИЗ которого перенесли
        if let index = vkPhotos.index(of: event.vkPhoto) {
            state.totalCount -= 1
            photosQueue.async(flags: .barrier) { [unowned self] in
                let vkPhoto = self.state.vkPhotos.remove(at: index)

                DispatchQueue.main.async { [weak self] in
                    self?.onVKPhotosUpdate?([vkPhoto])
                }
            }
        // 2. Это альбом В который перенесли
        } else if event.targetVKAlbum == vkAlbum {
            state.totalCount += 1
            isPhotosAdded = true

            photosQueue.async(flags: .barrier) { [unowned self] in
                self.state.vkPhotos.insert(event.vkPhoto, at: 0)

                DispatchQueue.main.async { [weak self] in
                    guard let vkPhoto = self?.vkPhotos[0] else { return }
                    self?.onVKPhotosUpdate?([vkPhoto])
                }
            }
        }
    }

    override func onVKPhotosMoved(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosMovedEvent,
            !event.vkPhotos.isEmpty
            else { return }

        var updatedVKPhotos = [VKPhoto]()
        event.vkPhotos.forEach { vkPhoto in
            if let index = vkPhotos.index(of: vkPhoto), event.fromVKAlbum == vkAlbum {
                state.totalCount -= 1
                updatedVKPhotos.append(vkPhotos[index])

                photosQueue.async(flags: .barrier) { [unowned self] in
                    self.state.vkPhotos.remove(at: index)
                }
            } else if event.targetVKAlbum == vkAlbum {
                state.totalCount += 1
                isPhotosAdded = true
                photosQueue.async(flags: .barrier) { [unowned self] in
                    self.state.vkPhotos.insert(vkPhoto, at: 0)
                }
            }
        }

        if updatedVKPhotos.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.onVKPhotosUpdate?(updatedVKPhotos)
        }
    }

    override func onVKPhotosUploaded(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosUploadedEvent,
            !event.vkPhotos.isEmpty && event.targetVKAlbum == vkAlbum
            else { return }

        super.onVKPhotosUploaded(notification)
    }

    fileprivate override func subscribe() {
        super.subscribe()
        startListen(.vkPhotosCopied, self, #selector(onVKPhotoCopied))
    }

    fileprivate override func fetchVKPhotos(count: Int, offset: Int) -> Promise<VKPhotosResult> {
        return api.fetchPhotosInAlbum(albumId: vkAlbum.id, count: count, offset: offset)
            .then { [weak self] vkPhotos, totalCount in
                guard let vkAlbum = self?.vkAlbum else { return }

                // TODO!! Должна быть отдельная операция VKPhotosFetchOperation
                dispatch(.vkPhotosFetched,
                    VKPhotosFetchedEvent(vkPhotos: vkPhotos, totalCount: totalCount, inVKAlbum: vkAlbum)
                )
            }
    }
}
