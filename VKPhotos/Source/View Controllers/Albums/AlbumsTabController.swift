//
//  AlbumsTabController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 07/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Hydra
import Firebase

class AlbumsTabController: UIViewController {
    let openAlbumFormSegueID = "showAlbumForm"
    let openAlbumPhotosGridSegueID = "showAlbumPhotosSegue"

    @IBOutlet weak var editBarButton: UIBarButtonItem!
    @IBOutlet weak var vkAlbumsGrid: AlbumsGridCollection! {
        didSet {
            vkAlbumsGrid.setup(withDelegate: self)
            vkAlbumsGrid.scrollDelegate = self
            vkAlbumsGrid.isShouldEndScrollReachingFire = { [weak self] _ in
                guard let this = self else { return false }

                return
                    this.albumManager.vkAlbums.count != 0 &&
                    this.albumManager.vkAlbums.count < this.albumManager.totalCount
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    private let ALBUMS_PER_PAGE = 32
    private var albumManager: (AlbumManager & VKAPIManager)!
    private var isNeedToReload = false // Нужно обновить сетку данными с АПИ

    override func viewDidLoad() {
        super.viewDidLoad()

        albumManager = VKAlbumManager()
        subscribe()

        vkAlbumsGrid.footer.startLoading()
        albumManager.getAlbums(count: ALBUMS_PER_PAGE, true)
            .then { [weak self] vkAlbums in
                self?.vkAlbumsGrid.footer.hide(withAnim: false)
                self?.vkAlbumsGrid.reloadData(vkAlbums) { [weak self] in
                    self?.showCounterInGridFooter()
                }
            }
            .catch { [weak self] error in
                guard let isRefreshing = self?.vkAlbumsGrid.isRefreshing, !isRefreshing else { return }
                if let error = error as? VKApiClientErrors, case .RequestCancelled = error {
                    self?.vkAlbumsGrid.footer.stopLoading(Messages.Errors.needToRefreshList)
                    return
                }

                var popErrorMessage = Messages.Errors.failToFetchNewData
                if let error = error as? VKApiClientErrors, case .NoInternetConnection = error {
                    popErrorMessage = Messages.Errors.noInternetConnection
                }

                self?.showErrorNotification(popErrorMessage)
                self?.vkAlbumsGrid.footer.stopLoading(Messages.Errors.needToRefreshList)
            }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isNeedToReload {
            reloadAlbumsGridFromServer { [weak self] in
                self?.isNeedToReload = false
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Вдруг disappear сработает быстрее чем завершится didLoad :O А такое может быть!
        guard albumManager != nil else { return }

        // TODO: Надо отменять все вызовы и приводить UI грида в порядок
        albumManager.cancelAllRequests { [weak self] in
            self?.vkAlbumsGrid.isScrollEndReached = false
            self?.vkAlbumsGrid.refreshControl?.endRefreshing()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Open Album Photos Grid
        if segue.identifier == openAlbumPhotosGridSegueID, let vkAlbum = sender as? VKAlbum {
            let albumViewController = segue.destination as! AlbumPhotosViewController
            albumViewController.vkAlbum = vkAlbum
        }

        // Open Album Form
        if segue.identifier == openAlbumFormSegueID {
            let navigationController = segue.destination as! UINavigationController
            if let albumFormController = navigationController.topViewController as? AlbumFormController {
                albumFormController.delegate = self

                if let vkAlbum = sender as? VKAlbum, vkAlbumsGrid.isEditMode {
                    albumFormController.vkAlbumToEdit = vkAlbum
                }
            }
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        vkAlbumsGrid.collectionViewLayout.invalidateLayout()
    }

    @IBAction func newAlbumButtonTap(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showAlbumForm", sender: nil)
    }

    @IBAction func editButtonTap(_ sender: UIBarButtonItem) {
        vkAlbumsGrid.toggleEditMode()
        editBarButton.title = vkAlbumsGrid.isEditMode ? "Done".localized() : "Edit".localized()
        editBarButton.style = vkAlbumsGrid.isEditMode ? .done : .plain
    }

    fileprivate func updateAlbumsGridFromState() {
        vkAlbumsGrid.footer.hide()
        vkAlbumsGrid.reloadData(albumManager.vkAlbums) { [weak self] in
            // TODO: Сделать добор до красоты
            self?.showCounterInGridFooter()
        }
    }

    fileprivate func reloadAlbumsGridFromServer(_ completion: (() -> Void)? = nil) {
        let count = albumManager.vkAlbums.count
        guard count > 0 else { return }

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        albumManager.getAlbums(count: count, true)
            .then { [weak self] vkAlbums in
                self?.vkAlbumsGrid.footer.hide()
                self?.vkAlbumsGrid.reloadData(vkAlbums) { [weak self] in
                    self?.showCounterInGridFooter()
                    completion?()
                }
            }
            .catch { [weak self] _ in
                self?.showErrorNotification(Messages.Errors.failToRefreshData)
                self?.vkAlbumsGrid.footer.stopLoading(Messages.Errors.needToReloadData)
            }
            .always(in: .main) {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
    }

    fileprivate func showCounterInGridFooter() {
        let text = getTextForAlbumsCount(count: albumManager.vkAlbums.count, totalCount: albumManager.totalCount)
        vkAlbumsGrid.footer.stopLoading(text)
    }

    fileprivate func getTextForAlbumsCount(count: Int, totalCount: Int) -> String {
        var text = "No Albums".localized()

        if count > 0 {
            let index = count % 10 == 1 && count % 100 != 11
                ? 0
                : count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20) ? 1 : 2

            let albumPlural = ["one album".localized(), "few albums".localized(), "many albums".localized()][index]
            text = "\(count) \(albumPlural)"

            if count < totalCount {
                text += " " + "of".localized() + " \(totalCount)"
            }
        }

        return text
    }
}

extension AlbumsTabController {
    private func subscribe() {
        albumManager.onAlbumsAdd = { [weak self] _ in
            // Сейчас альбом добавить можно только из одного места - формы создания
            // Поэтому нет ничего плохого чтобы запросить список альбомов заного
            self?.isNeedToReload = true
        }

        albumManager.onAlbumsDelete = { [weak self] _ in
            self?.updateAlbumsGridFromState()
        }

        albumManager.onAlbumsUpdate = { [weak self] _ in
            self?.isNeedToReload = true
        }
    }
}

extension AlbumsTabController: InfinityGridDelegate {
    func onRefresh() {
        albumManager.cancelAllRequests { [weak self] in
            self?.vkAlbumsGrid.footer.hide() // TODO: А не внтури ли скрывать?
            self?.albumManager.getAlbums(count: (self?.ALBUMS_PER_PAGE)!, true)
                .then { [weak self] vkAlbums in
                    self?.vkAlbumsGrid.reloadData(vkAlbums) { [weak self] in
                        self?.showCounterInGridFooter()
                    }
                }
                .catch { [weak self] error in
                    guard let this = self else { return }
                    let errorMessage = this.albumManager.vkAlbums.isEmpty
                        ? Messages.Errors.needToRefreshList
                        : Messages.Errors.needToReloadData

                    var popErrorMessage = Messages.Errors.failToRefreshData
                    if let error = error as? VKApiClientErrors, case .NoInternetConnection = error {
                        popErrorMessage = Messages.Errors.noInternetConnection
                    }

                    this.showErrorNotification(popErrorMessage)
                    this.vkAlbumsGrid.footer.stopLoading(errorMessage)
                }
                .always(in: .main) { [weak self] in
                    // TODO: Здесь что-то не чисто, надо поставить аналитику на рефреш
                    self?.vkAlbumsGrid.refreshControl?.endRefreshing()
            }
        }
    }

    func onScrollEndReached() {
        if vkAlbumsGrid.isRefreshing {
            vkAlbumsGrid.isScrollEndReached = false
            return
        }

        vkAlbumsGrid.footer.startLoading()
        albumManager.getNextAlbums(count: ALBUMS_PER_PAGE, true)
            .then { [weak self] _ in
                guard let vkAlbums = self?.albumManager.vkAlbums else { return }
                self?.vkAlbumsGrid.footer.hide()
                self?.vkAlbumsGrid.reloadData(vkAlbums) { [weak self] in
                    self?.showCounterInGridFooter()
                    self?.vkAlbumsGrid.isScrollEndReached = false
                }
            }
            .catch { [weak self] error in
                if let error = error as? VKApiClientErrors, case .RequestCancelled = error {
                    self?.showCounterInGridFooter()
                    self?.vkAlbumsGrid.isScrollEndReached = false
                    return
                }

                var popErrorMessage = Messages.Errors.failToFetchNewData
                if let error = error as? VKApiClientErrors, case .NoInternetConnection = error {
                    popErrorMessage = Messages.Errors.noInternetConnection
                }

                self?.showErrorNotification(popErrorMessage)
                self?.vkAlbumsGrid.footer.stopLoading(Messages.Errors.needToReloadData)

                Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in // TODO: Защита от спама при моментальном отлупе
                    self?.vkAlbumsGrid.isScrollEndReached = false
                }
            }
    }
}

extension AlbumsTabController: AlbumsGridDelegate {
    func albumDidSelected(vkAlbum: VKAlbum) {
        if vkAlbumsGrid.isEditMode && vkAlbum.isSystem { return }

        let segueId = vkAlbumsGrid.isEditMode ? openAlbumFormSegueID : openAlbumPhotosGridSegueID
        performSegue(withIdentifier: segueId, sender: vkAlbum)
    }

    func albumDelete(_ vkAlbum: VKAlbum) {
        guard !vkAlbum.isSystem else { return }

        let deleteAction = UIAlertAction(title: "Delete".localized(), style: .destructive) { [weak self] _ in
            Analytics.logEvent(AnalyticsEvent.AlbumDelete, parameters: ["source": "grid"])

            var isShowingHUD = true
            let operation = self?.albumManager.deleteAlbum(vkAlbum) { result in
                isShowingHUD = false

                switch result {
                case .success(let isDeleted):
                    if isDeleted { HUD.hide(afterDelay: 0); return }
                    HUD.flash(.error, delay: 1.3)
                case .failure(let error):
                    if error == .cancelled { HUD.hide(); return }
                    HUD.flash(.error, delay: 1.3)
                }
            }

            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                guard isShowingHUD, let operation = operation else { return }
                HUD.show(cancelHandler: { operation.cancel() }) // TODO: Ну отмена точно должна быть в менеджере или где-то там
            }
        }

        let deleteActionSheet = UIAlertController(
            title: "Delete".localized() + " \"\(vkAlbum.title)\"?",
            message: "Album and all photos in it will be permanently deleted. This cannot be undone.".localized(),
            preferredStyle: .actionSheet)

        deleteActionSheet.addAction(deleteAction)
        deleteActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        present(deleteActionSheet, animated: true)
    }
}

extension AlbumsTabController: AlbumFormDelegate {
    func albumDelete(_ vkAlbum: VKAlbum, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation? {
        Analytics.logEvent(AnalyticsEvent.AlbumDelete, parameters: ["source": "form"])

        return albumManager.deleteAlbum(vkAlbum) { result in
            switch result {
            case .success(let isDeleted): completion((isDeleted, false))
            case .failure(let error): completion((false, error == .cancelled))
            }
        }
    }

    func albumCreate(_ dto: VKAlbumDTO, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation? {
        Analytics.logEvent(AnalyticsEvent.AlbumCreate, parameters: [
            "view_privacy": dto.viewPrivacy.privacyAccess?.rawValue ?? "",
            "comment_privacy": dto.commentPrivacy.privacyAccess?.rawValue ?? ""
        ])

        return albumManager.createAlbum(dto) { result in
            switch result {
            case .success: completion((true, false))
            case .failure(let error): completion((false, error == .cancelled))
            }
        }
    }

    func albumEdit(_ dto: VKAlbumDTO, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation? {
        Analytics.logEvent(AnalyticsEvent.AlbumEdit, parameters: nil)

        return albumManager.editAlbum(dto) { result in
            switch result {
            case .success: completion((true, false))
            case .failure(let error): completion((false, error == .cancelled))
            }
        }
    }
}
