//
// Created by Yury Smidovich on 17/03/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import DeepDiff
import Hydra
import Firebase

protocol PhotosGridControllerDelegate: class {
    func changeNavigationUI(tabBar tabBarView: UIView, navigationTitle navigationTitleView: UIView)
    func resetNavigationUI()
}

class PhotosGridController: UIViewController {
    let PHOTOS_PER_PAGE = 104

    // TODO: Флаг означает - можно ли переводить сетку фоток в режим выбора
    // сейчас нужен для того чтобы решить визуальный баг, когда не появляются чекбоксы на фотках
    // если быстро нажать кнопку Изм. после перехода на экран с сеткой
    private var isCanStartSelect = false

    private(set) var isEditMode = false
    var photoManager: (PhotoManager & VKAPIManager)!

    var selectedVKPhotos = Set<VKPhoto>() {
        didSet {
            editTabBar.toggleButtonsAvailability()
            updateSelectedCounter()
        }
    }

    weak var parentController: PhotosGridControllerDelegate? // TODO: Переименовать: это скорее контроллер который отвечает за представление навигации
    weak var photoGallery: SlideLeafViewController?
    weak var vkPhotoDetailView: VKPhotoDetailView?
    weak var photosGridCollection: PhotosGridCollection! {
        didSet {
            photosGridCollection.setup(self)
            photosGridCollection.scrollDelegate = self
            photosGridCollection.isShouldEndScrollReachingFire = { [weak self] _ in
                guard let this = self else { return false }

                return
                    // 1) Если фотографий нет, то мы не можем запросить след порцию
                    this.photoManager.vkPhotos.count != 0 &&
                    // 2) Запрашиваем только если фотографий меньше чем totalCount
                    this.photoManager.vkPhotos.count < this.photoManager.totalCount
            }
        }
    }

    lazy var editBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "Edit".localized(), style: .plain, target: self, action: #selector(onEditBarButtonTap))
        button.tintColor = .white
        return button
    }()

    lazy var selectedPhotosCounter: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.sizeToFit()
        return label
    }()

    lazy var editTabBar: PhotosListEditTabbar = {
        let tabBar: PhotosListEditTabbar = .fromNib()
        tabBar.delegate = self
        return tabBar
    }()

    @objc func onEditBarButtonTap(_ sender: UIBarButtonItem) {
        if !isCanStartSelect || photoManager.vkPhotos.isEmpty { return }
        changeEditMode()
    }

    @objc func onVKUserBlockEvents(_ notification: NSNotification) {
        photosGridCollection.reloadData()
        photoGallery?.collectionView.reloadData()
    }

    func createPhotoManager() -> (PhotoManager & VKAPIManager) {
        return VKPhotoManager(key: "all")
    }

    func photoGalleryDidOpen() {}

    func photoGalleryDidClosed() {
        vkPhotoDetailView = nil
    }

    func updateGridFromState(_ loadMissing: Bool = true, completion: (() -> Void)? = nil) {
        // Добор это опасная и не очень необходимая штука
        // Если что-то не так - первым делом ищи причину тут 👇
        let loadMissingPhotos: (Int) -> Void = { [weak self] count in
            self?.photosGridCollection.isScrollEndReached = true
            self?.photoManager.getNextPhotos(count: count) { [weak self] result in
                switch result {

                case .success(let vkPhotos):
                    guard let this = self else { return }

                    this.photoGallery?.update(vkPhotos, from: this.photoManager.vkPhotos)
                    this.photosGridCollection.footer.hide(withAnim: false)

                    this.photosGridCollection.insertPhotos(vkPhotos) { [weak self] in
                        self?.photosGridCollection.isScrollEndReached = false
                        self?.showFooterMessageWithCounter()
                        completion?()
                    }

                case .failure:
                    self?.photosGridCollection.isScrollEndReached = false
                    completion?()
                }
            }
        }

        // TODO!!! Это очень стремно: фильтровать надо где-то в другом месте
        let vkPhotos = photoManager.vkPhotos.filter({ !$0.isDeleted })
        photosGridCollection.reloadPhotos(with: vkPhotos) { [weak self] in
            self?.showFooterMessageWithCounter()

            guard let this = self, loadMissing else { completion?(); return }

            // Добор
            let vkPhotosCount = this.photoManager.vkPhotos.count
            if vkPhotosCount < this.PHOTOS_PER_PAGE {
                // 1) Догружаем до `PHOTOS_PER_PAGE`
                let missingCount = this.PHOTOS_PER_PAGE - vkPhotosCount
                if missingCount > 0 && vkPhotosCount < this.photoManager.totalCount {
                    loadMissingPhotos(missingCount)
                } else {
                    completion?()
                }
            } else {
                // 2) Догружаем до "красоты"
                let currentCountInGrid = this.photosGridCollection.vkPhotos.count
                let rows = Float(currentCountInGrid) / Float(this.photosGridCollection.itemsPerRow)
                let missingCount = (Int(rows.rounded(.up)) * this.photosGridCollection.itemsPerRow) - currentCountInGrid

                guard missingCount > 0 else { completion?(); return }
                loadMissingPhotos(missingCount)
            }
        }
    }

    func onVKPhotosUpdate(_ updatedVKPhotos: [VKPhoto]) {
        // TODO: Дизейблить кнопку изменения (выбора) если фоток нет
        //editBarButton.isEnabled = !photoManager.vkPhotos.isEmpty

        photoGallery?.update(updatedVKPhotos, from: photoManager.vkPhotos)
        updateGridFromState()
        cleanupSelectedVKPhotos()
    }

    func changeEditMode(to forceValue: Bool? = nil) {
        if let forceValue = forceValue, forceValue == isEditMode { return }
        isEditMode = forceValue != nil ? forceValue! : !isEditMode

        photosGridCollection.toggleIsSelectable(to: isEditMode)

        editBarButton.title = isEditMode ? "Cancel".localized() : "Edit".localized()
        editBarButton.style = isEditMode ? .done : .plain

        if isEditMode {
            updateSelectedCounter()
            parentController?.changeNavigationUI(tabBar: editTabBar, navigationTitle: selectedPhotosCounter)
        } else {
            parentController?.resetNavigationUI()
            editTabBar.removeFromSuperview()
            selectedVKPhotos.removeAll()
        }
    }

    func multipleMove() {
        // На данный момент массовое перемещение можно сделать только из контроллера альбома
    }

    func multipleDelete() {
        guard !selectedVKPhotos.isEmpty else { HUD.flash(.error, delay: 1.3); return }

        let title = "Delete".localized() + " \(selectedVKPhotos.count) " + "photos".localized()
        let deleteAction = UIAlertAction(title: title, style: .destructive) { [weak self] _ in
            guard let this = self else { return }
            var isShowingHUD = true

            let operation = this.photoManager.multiDelete(Array(this.selectedVKPhotos)) { [weak self] result in
                isShowingHUD = false
                self?.photoManager.cleanupState(nil)

                switch result {
                case .success:
                    self?.changeEditMode(to: false)
                    HUD.hide(animated: true)
                    StoreReviewHelper.checkAndAskForReview()
                case .failure(let error):
                    guard error != .cancelled else { return }
                    HUD.flash(.error, delay: 1.3)
                }

                // TODO: Обновить сетку синкой или из стейта?
            }

            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                guard isShowingHUD, let operation = operation else { return }
                HUD.show(cancelHandler: { operation.cancel() })
            }

            Analytics.logEvent(AnalyticsEvent.PhotoMultiDelete, parameters: ["count": this.selectedVKPhotos.count])
        }

        let deleteActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        deleteActionSheet.addAction(deleteAction)
        deleteActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        present(deleteActionSheet, animated: true)
    }

    fileprivate func updateSelectedCounter() {
        selectedPhotosCounter.text = "\(selectedVKPhotos.count) " + "of".localized() + " \(photoManager.totalCount)"
        selectedPhotosCounter.sizeToFit()
    }

    fileprivate func cleanupSelectedVKPhotos() {
        if isEditMode && photoManager.vkPhotos.isEmpty {
            // TODO: Есть четкое ощущение что это здесь не должно быть
            changeEditMode(to: false)
        }

        if !selectedVKPhotos.isEmpty {
            selectedVKPhotos = selectedVKPhotos.filter({ photoManager.vkPhotos.contains($0) })
        }
    }

    fileprivate func showFooterMessageWithCounter() {
        let text = getTextForPhotosCount(count: photoManager.vkPhotos.count, totalCount: photoManager.totalCount)
        photosGridCollection.footer.stopLoading(text)
    }

    fileprivate func handleError(_ error: OperationError, _ popErrorMessage: String? = nil, _ footerErrorMessage: String? = nil) {
        var errorMessage = popErrorMessage ?? Messages.Errors.failToRefreshData
        if error == .noConnection {
            errorMessage = Messages.Errors.noInternetConnection
        }

        showErrorNotification(errorMessage)
        photosGridCollection.footer.stopLoading(footerErrorMessage ?? Messages.Errors.needToRefreshList)

        // TODO! Показать кнопку "Обновить"
    }

    fileprivate func getTextForPhotosCount(count: Int, totalCount: Int) -> String {
        var text: String = "No Photo".localized()

        if count > 0 {
            let index = count % 10 == 1 && count % 100 != 11
                ? 0
                : count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20) ? 1 : 2

            let photosPlural = ["one photo".localized(), "few photos".localized(), "many photos".localized()][index]
            text = "\(count) \(photosPlural)"

            if count < totalCount {
                text += " " + "of".localized() + " \(totalCount)"
            }
        }

        return text
    }

    fileprivate func prefetchPhotoInfo(for nextIndex: Int, with currentIndex: Int) {
        // TODO!! Отменять запросы или не давать делать новые
        let photosCount = photoManager.vkPhotos.count
        var indices = 0 ... 1

        if nextIndex == currentIndex {
            // 1) Мы только что, открыли галерею, а значит подгружаем 1 фотку влево 1 вправо и текущую
            indices = nextIndex - 1 ... nextIndex + 1
        } else {
            // 2) Мы в галерее и сейчас будет подгружаться следующая фото, надо получить инфу для ее след 3 соседях
            indices = currentIndex < nextIndex
                ? nextIndex + 1...nextIndex + 3
                : nextIndex - 3...nextIndex - 1
        }

        let siblingIndex = currentIndex < nextIndex
            ? (nextIndex + 1 >= photosCount ? nextIndex : nextIndex + 1)
            : (nextIndex - 1 < 0 ? nextIndex : nextIndex - 1)

        guard // Если для фотки через одну, инфа не загружена, только тогда подгружаем след батч из 3х (или менее)
            (nextIndex >= 0 && nextIndex < photosCount),
            photoManager.vkPhotos[siblingIndex].isInfoExist == false || nextIndex == currentIndex
            else { return }

        let idxsForUpdate = indices.filter({ $0 >= 0 && $0 < photosCount })
        let vkPhotosToUpdate = idxsForUpdate.compactMap { idx -> VKPhoto? in
            let vkPhoto = photoManager.vkPhotos[idx]
            return vkPhoto.isInfoExist ? nil : vkPhoto
        }

        guard !vkPhotosToUpdate.isEmpty else { return }
        photoManager.updatePhotosInfo(vkPhotosToUpdate, { _ in })
    }
}

// MARK: Lifecycle -
extension PhotosGridController {

    override func viewDidLoad() {
        super.viewDidLoad()

        startListen(.vkUserBlocked, self, #selector(onVKUserBlockEvents))
        startListen(.vkUserUnblocked, self, #selector(onVKUserBlockEvents))

        photoManager = createPhotoManager()
        photoManager.onVKPhotosUpdate = onVKPhotosUpdate
        photoManager.onTotalCountUpdate = { [weak self] _ in
            // Это здесь потому что totalCount может обновиться, а adjust для фотки может не вызываться
            // TODO: 1 из 0 при перемещении последней фотки
            self?.vkPhotoDetailView?.updateTitleCounter()
        }

        guard photoManager.vkPhotos.isEmpty else { return }

        /// Кейс 1: Список пустой, добавляем в него первую порцию фотографий
        photosGridCollection.footer.startLoading()
        photoManager.getPhotos(count: PHOTOS_PER_PAGE) { [weak self] result in
            guard let this = self else { return }

            switch result {

            case .success(let vkPhotos):
                this.photosGridCollection.footer.hide(withAnim: false)
                this.photosGridCollection.insertPhotos(vkPhotos) { [weak self] in
                    self?.showFooterMessageWithCounter()
                }

            case .failure(let error):
                guard
                    let isRefreshing = self?.photosGridCollection.isRefreshing, !isRefreshing
                    else { return }

                if error == .cancelled {
                    self?.photosGridCollection.footer.stopLoading(Messages.Errors.needToRefreshList)
                    return
                }

                self?.handleError(error)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        photoManager.cleanupState { [weak self] isNeedToReload in
            if isNeedToReload { self?.updateGridFromState() }
            self?.cleanupSelectedVKPhotos()
        }

        isCanStartSelect = true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        photosGridCollection.collectionViewLayout.invalidateLayout()
    }
}

extension PhotosGridController: InfinityGridDelegate {
    func onRefresh() {
        /// Кейс: Если происходит подгрузка новой порции, но мы запросили обновление списка
        // TODO!!! Отменит ВСЕ запросы: в том числе на удаление фото и тп
        photoManager.cancelAllRequests { [weak self] in

            self?.photoManager.getPhotos(count: (self?.PHOTOS_PER_PAGE)!) { [weak self] result in
                self?.photosGridCollection.refreshControl?.endRefreshing()

                switch result {
                case .success(let vkPhotos):
                    if let itemsInList = self?.photosGridCollection.vkPhotos, itemsInList.count == 0 {
                        // Скрываем сообщение в футере до начала анимации
                        self?.photosGridCollection.footer.hide(withAnim: false)
                    }

                    self?.photosGridCollection.reloadPhotos(with: vkPhotos) { [weak self] in
                        self?.showFooterMessageWithCounter()
                    }

                    self?.cleanupSelectedVKPhotos()

                case .failure(let error):
                    self?.handleError(error)
                }

                self?.photosGridCollection.isScrollEndReached = false // На всякий случай!
            }
        }
    }

    func onScrollEndReached() {
        /// Кейс! Мы РЕФРЕШИМ список, долистываем до конца списка и начинаем подгрузку новой порции
        if (photosGridCollection.refreshControl?.isRefreshing)! {
            /* TODO!! Находясь в конце списка и наблюдая спинер подгрузки, после обновления всего списка
                      мы получим пустой футер без описания состояния. И только после движения списка,
                      начнется подгрузка след порции. */
            photosGridCollection.isScrollEndReached = false
            return
        }

        /// Кейс 3: Список полный - добавляем в него новую порцию
        photosGridCollection.footer.startLoading()
        photoManager.getNextPhotos(count: PHOTOS_PER_PAGE) { [weak self] result in

            switch result {
            case .success(let vkPhotos):
                if vkPhotos.count > 0, let state = self?.photoManager.vkPhotos {
                    self?.photoGallery?.update(vkPhotos, from: state)
                }

                self?.photosGridCollection.footer.hide(withAnim: false)
                self?.photosGridCollection.insertPhotos(vkPhotos) { [weak self] in
                    self?.photosGridCollection.isScrollEndReached = false
                    self?.showFooterMessageWithCounter()
                }

                self?.cleanupSelectedVKPhotos()

            case .failure(let error):
                if error == .cancelled {
                    self?.showFooterMessageWithCounter()
                    self?.photosGridCollection.isScrollEndReached = false
                    return
                }

                var errorMessage = Messages.Errors.failToFetchNewData
                if error == .dataInconsistency {
                    // `isScrollEndReached` я намеренно ставлю в `true` чтобы не было возможности
                    // дальше запрашивать фотографии без полного обновления списка
                    errorMessage = Messages.Errors.dataInconsistency
                    self?.photosGridCollection.isScrollEndReached = true
                } else {
                    Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
                        self?.photosGridCollection.isScrollEndReached = false
                    }
                }

                self?.handleError(error, errorMessage, Messages.Errors.needToReloadData)
            }
        }
    }
}

// MARK: Photos Grid Delegate
extension PhotosGridController: PhotosGridDelegate {

    func tapVKPhoto(inCell cell: PhotosGridCell, atIndex: Int) {
        guard cell.imageView.image != nil else { return }

        vkPhotoDetailView = VKPhotoDetailView.fromNib()
        vkPhotoDetailView!.delegate = self

        photoGallery = SlideLeafViewController.make(
            photos: photoManager.vkPhotos,
            startPageIndex: atIndex,
            fromImageView: cell.imageView,
            photoDetailView: vkPhotoDetailView
        )

        photoGallery!.delegate = self
        photoGallery?.willDisplayPhotoAt = prefetchPhotoInfo

        present(photoGallery!, animated: true) { [weak self] in
            self?.photoGalleryDidOpen()
        }
    }

    func selectVKPhoto(_ vkPhoto: VKPhoto, _ result: ((Bool) -> Void)) {
        guard
            photoManager.vkPhotos.contains(where: { $0 == vkPhoto && !$0.isDeleted })
            else { result(false); return }

        result(selectedVKPhotos.insert(vkPhoto).inserted)
    }

    func deselectVKPhoto(_ vkPhoto: VKPhoto, _ result: ((Bool) -> Void)) {
        result(selectedVKPhotos.remove(vkPhoto) != nil)
    }

    func isVKPhotoSelected(_ vkPhoto: VKPhoto) -> Bool {
        return selectedVKPhotos.contains(vkPhoto)
    }
}

extension PhotosGridController: VKPhotoDetailViewDelegate {
    var vkPhotosTotalCount: Int {
        // Не забывай, что в галерее остаются удаленные фотографии
        return photoManager.totalCount + photoManager.vkPhotos.filter({ $0.isDeleted }).count
    }

    func makeCoverVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.makeCover(vkPhoto) { result in
            switch result {
            case .success(let isSuccess): completion?((isSuccess, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func moveVKPhoto(_ vkPhoto: VKPhoto, toVKAlbum: VKAlbum, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.movePhoto(vkPhoto, toVKAlbum) { result in
            switch result {
            case .success: completion?((true, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func copyVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.copyPhoto(vkPhoto) { result in
            switch result {
            case .success: completion?((true, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func editVKPhotoText(_ vkPhoto: VKPhoto, text: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.editPhotoCaption(vkPhoto, caption: text) { result in
            switch result {
            case .success(let isEdited): completion?((isEdited, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func tapLikeButton(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) {
        // TODO!! Мы не аджастим фотку после лайка или дизлайка по причинам:
        // 1) В интерфейсе фотка уже имеет актуальный статус лайка/дизлайка
        // 2) Из-за того, что лайк имеет дебаунс, интерфейс галереи может вести себя некорректно
        //    например терять зум, фризиться при слайде и т.д.

        if vkPhoto.isLiked {
            // Это потому что фотка из VKPhotoDetailView приехала лайкнутой, но на деле ее только предстоит лайкнуть
            photoManager.likePhoto(vkPhoto) { result in
                switch result {
                case .success: completion?((true, false))
                case .failure(let error): completion?((false, error == .cancelled))
                }
            }
        } else {
            photoManager.dislikePhoto(vkPhoto) { result in
                switch result {
                case .success: completion?((true, false))
                case .failure(let error): completion?((false, error == .cancelled))
                }
            }
        }
    }

    func deleteVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.deletePhoto(vkPhoto) { result in
            switch result {
            case .success(let isDeleted): completion?((isDeleted, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func tapRestoreButton(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.restorePhoto(vkPhoto) { result in
            switch result {
            case .success(let isRestored): completion?((isRestored, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func reportVKPhoto(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        return photoManager.reportAndDislike(vkPhoto, reason) { result in
            switch result {
            case .success(let isReported): completion?((isReported, false))
            case .failure(let error): completion?((false, error == .cancelled))
            }
        }
    }

    func tapCancelOperation(_ operation: AsyncOperation) {
        operation.cancel()
    }
}

// MARK: Gallery -
extension PhotosGridController: SlideLeafViewControllerDelegate {
    func longPressImageView(slideLeafViewController: SlideLeafViewController, photo: VKPhoto, pageIndex: Int) {}

    func photoDidDisplayed(atIndex index: Int) {
        guard index < photosGridCollection.vkPhotos.count else { return }
        let indexPath = IndexPath(item: index, section: 0)
        photosGridCollection.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
    }

    func browserDismissed(photo: VKPhoto, pageIndex: Int) {
        photoGalleryDidClosed()
    }
}

// MARK: Multi Edit -
extension PhotosGridController: EditablePhotosList {
    // TODO Избавиться от objc
    @objc var isMoveButtonEnabled: Bool {
        return !selectedVKPhotos.isEmpty && !selectedVKPhotos.contains(where: { !$0.isCurrentUserOwner || $0.isDeleted })
    }

    var isDeleteButtonEnabled: Bool {
        return !selectedVKPhotos.isEmpty && !selectedVKPhotos.contains(where: { !$0.isCurrentUserOwner || $0.isDeleted })
    }

    func onDeleteButtonTap() {
        multipleDelete()
    }

    func onMoveButtonTap() {
        multipleMove()
    }
}
