//
//  AlbumManager.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 16/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Foundation
import Hydra

protocol AlbumManager: class {
    var vkAlbums: [VKAlbum] { get }
    var totalCount: Int { get }

    var onAlbumsAdd: (([VKAlbum]) -> Void)? { get set }
    var onAlbumsDelete: (([VKAlbum]) -> Void)? { get set }
    var onAlbumsUpdate: (([VKAlbum]) -> Void)? { get set }

    func getAlbums(count: Int, _ withSystems: Bool) -> Promise<[VKAlbum]>
    func getNextAlbums(count: Int, _ withSystems: Bool) -> Promise<[VKAlbum]>
    func deleteAlbum(_ album: VKAlbum, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKAlbumDeleteOperation?
    func createAlbum(_ dto: VKAlbumDTO, _ completion: @escaping (OperationResult<VKAlbum>) -> Void) -> VKAlbumCreateOperation?
    func editAlbum(_ dto: VKAlbumDTO, _ completion: @escaping (OperationResult<VKAlbum>) -> Void) -> VKAlbumEditOperation?
}

class VKAlbumManager: AlbumManager {
    deinit {
        api.token.invalidate()
    }

    typealias VKAlbumsState = (vkAlbums: [VKAlbum], totalCount: Int)

    enum Errors: Error {
        case alreadyRun, operationFailed
    }

    var totalCount: Int { return state.totalCount }
    var vkAlbums: [VKAlbum] {
        var result = [VKAlbum]()
        albumsQueue.sync { result = state.vkAlbums }
        return result
    }

    var onAlbumsAdd: (([VKAlbum]) -> Void)?
    var onAlbumsDelete: (([VKAlbum]) -> Void)?
    var onAlbumsUpdate: (([VKAlbum]) -> Void)?

    private var state: VKAlbumsState = ([], 0)
    private var offset: Int {
        return state.vkAlbums.count
    }

    fileprivate let api = VKApiClient()
    fileprivate let apiOperations: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "io.vk_album_manager.api_operations"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    fileprivate let albumsQueue = DispatchQueue(label: "io.vk_album_manager.albums", attributes: .concurrent)
    fileprivate var reloadRequestState: RequestState = .done
    fileprivate var loadMoreRequestState: RequestState = .done

    init() {
        subscribe()
    }

    @objc func onAlbumCreated(_ notification: NSNotification) {
        guard let event = notification.object as? VKAlbumCreatedEvent else { return }
        let index = vkAlbums.filter({ $0.id < 0 }).count

        state.totalCount += 1
        albumsQueue.async(flags: .barrier) { [weak self] in
            self?.state.vkAlbums.insert(event.vkAlbum, at: index)

            DispatchQueue.main.async { [weak self] in
                guard
                    let count = self?.vkAlbums.count,
                    0 ..< count ~= index,
                    let vkAlbum = self?.vkAlbums[index]
                    else { return }

                self?.onAlbumsAdd?([vkAlbum])
            }
        }
    }

    @objc func onAlbumEdited(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKAlbumEditedEvent,
            let index = vkAlbums.index(of: event.vkAlbum)
            else { return }

        albumsQueue.async(flags: .barrier) { [weak self] in
            self?.state.vkAlbums[index] = event.vkAlbum

            DispatchQueue.main.async { [weak self] in
                self?.onAlbumsUpdate?([event.vkAlbum])
            }
        }
    }

    @objc func onAlbumsDeleted(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKAlbumsDeletedEvent,
            event.vkAlbums.count > 0
            else { return }

        let newAlbums = state.vkAlbums.filter({ !event.vkAlbums.contains($0) })
        state.totalCount -= state.vkAlbums.count - newAlbums.count
        albumsQueue.async(flags: .barrier) { [weak self] in
            self?.state.vkAlbums = newAlbums

            DispatchQueue.main.async { [weak self] in
                // TODO: Выкидывать в эвент реально удаленные из стейта альбомы
                self?.onAlbumsDelete?(event.vkAlbums)
            }
        }
    }

    @objc func onVKPhotosDeleted(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotosDeletedEvent else { return }
        onVKPhotosUpdated(event.vkPhotos)
    }

    @objc func onVKPhotosUploaded(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotosUploadedEvent else { return }
        onVKPhotosUpdated(event.vkPhotos)
    }

    @objc func onVKPhotosCopied(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoCopiedEvent else { return }
        onVKPhotosUpdated([event.vkPhoto])
    }

    @objc func onVKPhotoMoved(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotoMovedEvent else { return }
        onVKPhotosUpdated([event.vkPhoto])
    }

    @objc func onVKPhotosMoved(_ notification: NSNotification) {
        guard let event = notification.object as? VKPhotosMovedEvent else { return }
        onVKPhotosUpdated(event.vkPhotos)
    }

    @objc func onVKPhotoMakeCover(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotoMakeCoverEvent,
            let index = vkAlbums.index(where: { $0.id == event.vkPhoto.albumId })
            else { return }

        // TODO: Потенциально у альбома изменилась обложка и видимо ее надо тут запросить
        onAlbumsUpdate?([vkAlbums[index]])
    }

    @objc func onVKPhotosFetched(_ notification: NSNotification) {
        guard
            let event = notification.object as? VKPhotosFetchedEvent,
            let vkAlbum = event.inVKAlbum,
            let index = vkAlbums.index(of: vkAlbum),
            vkAlbums[index].photosCount != event.totalCount
            else { return }

        onAlbumsUpdate?([vkAlbums[index]])
    }

    func getAlbums(count: Int, _ withSystems: Bool = true) -> Promise<[VKAlbum]> {
        return Promise<[VKAlbum]> { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            if this.reloadRequestState == .execute {
                reject(Errors.alreadyRun); return
            }

            this.reloadRequestState = .execute

            this.fetchVKAlbums(count: count, offset: 0, isNeedSystem: withSystems)
                .then { [weak self] vkAlbums, totalCount in
                    self?.state.totalCount = totalCount
                    self?.albumsQueue.async(flags: .barrier) { [weak self] in
                        self?.state.vkAlbums = vkAlbums

                        DispatchQueue.main.async {
                            resolve(vkAlbums)
                        }
                    }
                }
                .catch { reject($0) }
                .always { [weak self] in self?.reloadRequestState = .done}
        }
    }

    func getNextAlbums(count: Int, _ withSystems: Bool = true) -> Promise<[VKAlbum]> {
        return Promise<[VKAlbum]> { [weak self] resolve, reject, _ in
            guard let this = self else { return }

            if this.loadMoreRequestState == .execute {
                reject(Errors.alreadyRun); return
            }

            this.loadMoreRequestState = .execute

            this.fetchVKAlbums(count: count, offset: this.offset, isNeedSystem: withSystems)
                .retry(2)
                .then { [weak self] vkAlbums, totalCount in
                    guard let this = self else { return }

                    let newVKAlbums = vkAlbums.unique(by: this.state.vkAlbums)

                    this.state.totalCount = totalCount
                    this.albumsQueue.async(flags: .barrier) { [weak self] in
                        self?.state.vkAlbums += newVKAlbums

                        DispatchQueue.main.async {
                            resolve(newVKAlbums)
                        }
                    }
                }
                .catch { reject($0) }
                .always { [weak self] in self?.loadMoreRequestState = .done }
        }
    }

    func createAlbum(_ dto: VKAlbumDTO, _ completion: @escaping (OperationResult<VKAlbum>) -> Void) -> VKAlbumCreateOperation? {
        let operation = VKAlbumCreateOperation(api, dto)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func deleteAlbum(_ album: VKAlbum, _ completion: @escaping (OperationResult<Bool>) -> Void) -> VKAlbumDeleteOperation? {
        let operation = VKAlbumDeleteOperation(api, album)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    func editAlbum(_ dto: VKAlbumDTO, _ completion: @escaping (OperationResult<VKAlbum>) -> Void) -> VKAlbumEditOperation? {
        let operation = VKAlbumEditOperation(api, dto)
        operation.completionBlock = operationCompletion(operation, completion)
        apiOperations.addOperation(operation)

        return operation
    }

    fileprivate func onVKPhotosUpdated(_ vkPhotos: [VKPhoto]) {
        let updatedAlbumsID = vkPhotos.map({ vkPhoto -> Int in return vkPhoto.albumId })
        let touchedVKAlbums = vkAlbums.filter({ vkAlbum -> Bool in
            return updatedAlbumsID.contains(where: { $0 == vkAlbum.id })
        })

        if !touchedVKAlbums.isEmpty {
            onAlbumsUpdate?(touchedVKAlbums)
        }
    }

    fileprivate func fetchVKAlbums(count: Int, offset: Int, isNeedSystem: Bool) -> Promise<VKApiClient.VKAlbumsResult> {
        return api.fetchAlbumsWithTotalCount(count: count, offset: offset, isNeedSystem: isNeedSystem)
    }

    fileprivate func subscribe() {
        startListen(.vkAlbumCreated, self, #selector(onAlbumCreated))
        startListen(.vkAlbumsDeleted, self, #selector(onAlbumsDeleted))
        startListen(.vkAlbumEdited, self, #selector(onAlbumEdited))

        startListen(.vkPhotosDeleted, self, #selector(onVKPhotosDeleted))
        startListen(.vkPhotosUploaded, self, #selector(onVKPhotosUploaded))
        startListen(.vkPhotosCopied, self, #selector(onVKPhotosCopied))
        startListen(.vkPhotoMoved, self, #selector(onVKPhotoMoved))
        startListen(.vkPhotosMoved, self, #selector(onVKPhotosMoved))
        startListen(.vkPhotoMakeCover, self, #selector(onVKPhotoMakeCover))
        startListen(.vkPhotosFetched, self, #selector(onVKPhotosFetched))
    }

    fileprivate func operationCompletion<T>(
        _ operation: APIOperation<T>,
        _ completion: @escaping ((OperationResult<T>) -> Void)
    ) -> () -> Void {
        return {
            if let error = operation.error {
                DispatchQueue.main.async {
                    completion(.failure(.fromError(error)))
                }
                return
            }

            if let result = operation.result {
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.failure(.failed))
            }
        }
    }
}

extension VKAlbumManager: VKAPIManager {
    func cancelAllRequests(then: (() -> Void)? = nil) {
        apiOperations.cancelAllOperations()

        api.token.invalidate()
        api.token = InvalidationToken()

        reloadRequestState = .done
        loadMoreRequestState = .done

        then?()
    }
}
