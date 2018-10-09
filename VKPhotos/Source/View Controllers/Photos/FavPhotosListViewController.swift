//
//  FavPhotosListViewController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Hydra

class FavPhotosListViewController: PhotosGridController {

    @IBOutlet override weak var photosGridCollection: PhotosGridCollection! {
        get { return super.photosGridCollection }
        set { super.photosGridCollection = newValue }
    }

    override func createPhotoManager() -> (PhotoManager & VKAPIManager) {
        return VKFavPhotoManager(key: "fav")
    }

    override func viewDidAppear(_ animated: Bool) {
        /* TODO!!! Что у нас тут происходит:
         1) Лайкаем фотку в режиме галереи - она добавляется в буфер лайкнутых в менеджере
         2) Дизлайкаем фотку и сразу закрываем галерею
         -3) Срабатывает `cleanup` из метода `super.photoGalleryDidClosed`-
         4) Лайкнутая фотка из буфера попадает в начало списка
         5) Тупящая сеть получает ответ от сервера на дизлайк из пункта 2
         6) Срабатывают события подключенные в `startListenLikes` и удаляют фотку из стейта

         Все это дает не очень красивый эффект в сетке фотографий, но кейс не очень частый

         UPD: Это не актуально, но оставлю чтобы помнить о проблеме
         */

        photoManager.onVKPhotosUpdate = { [weak self] updatedVKPhotos in
            self?.photoManager.cleanupState { [weak self] isNeedToReload in
                if isNeedToReload { self?.updateGridFromState() }
            }

            guard let photos = self?.photoManager.vkPhotos else { return }
            self?.photoGallery?.update(updatedVKPhotos, from: photos)
        }

        // Сетка избранного получила фокус - почистили
        photoManager.cleanupState { [weak self] isNeedToReload in
            // Избранное - это тяжкий раздел ВКонтакте, с кучей несостыковок
            // Поэтому после, казалось бы, отработавшей локальной чистки -
            // лучше засинкать состояние с сервером в фоне
            guard isNeedToReload else { self?.syncPhotos(); return }

            self?.updateGridFromState(false) { [weak self] in
                self?.syncPhotos()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        photoManager.onVKPhotosUpdate = onVKPhotosUpdate
    }

    private func syncPhotos() {
        photoManager.syncStateWithServer { [weak self] result in
            switch result {
            case .success: self?.updateGridFromState()
            case .failure: break // TODO: Никаких реакций точно не надо?
            }
        }
    }
}

extension FavPhotosListViewController: NavigationBarDelegate {
    var rightBarButton: UIBarButtonItem? { return nil }
}
