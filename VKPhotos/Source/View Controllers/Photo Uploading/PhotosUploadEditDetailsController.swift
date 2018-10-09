//
//  PhotosUploadEditDetailsController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 09/07/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

protocol PhotoCaptionEditingProtocol: class {
    func onCaptionSave(_ vkPhoto: VKPhoto, caption: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
}

// TODO Переименовать! VKPhotoEditDetailsController
class PhotosUploadEditDetailsController: UIViewController {
    var vkPhoto: VKPhoto?
    weak var delegate: PhotoCaptionEditingProtocol?

    @IBOutlet weak var captionTextView: UITextView! {
        didSet {
            captionTextView.textContainerInset = UIEdgeInsets(top: 4, left: 5, bottom: 5, right: 5)
            if let caption = vkPhoto?.text {
                captionTextView.text = caption
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            self.captionTextView.becomeFirstResponder()
        }
    }

    @IBAction func cancelBarButtonTap(_ sender: UIBarButtonItem) {
        if captionTextView.text.isEmpty || captionTextView.text == vkPhoto?.text {
            closeEditForm(); return
        }

        let saveActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let stopAction = UIAlertAction(title: "Don't Save".localized(), style: .destructive) { _ in self.closeEditForm() }

        saveActionSheet.addAction(stopAction)
        saveActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        present(saveActionSheet, animated: true)
    }

    @IBAction func saveBarButtonTap(_ sender: UIBarButtonItem) {
        guard
            let vkPhoto = vkPhoto, // Сохроняем если:
            (!vkPhoto.text.isEmpty && captionTextView.text.isEmpty) // 1) Стерли описание
            || vkPhoto.text != captionTextView.text // 2) Изменили описание
            else { closeEditForm(); return }

        var isShowingHUD = true

        let captionEditOperation = delegate?.onCaptionSave(vkPhoto, caption: captionTextView.text) { [weak self] result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.hide(afterDelay: 0)
                self?.closeEditForm()

                return
            }

            HUD.flash(.error, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = captionEditOperation else { return }
            HUD.show(cancelHandler: {
                operation.cancel() // TODO: Вынести это в общий протокол отмены операций
            })
        }
    }

    private func closeEditForm() {
        captionTextView.endEditing(true)
        dismiss(animated: true)
    }
}
