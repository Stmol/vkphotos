//
//  AlbumFormController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 29/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

protocol AlbumFormDelegate: class {
    func albumCreate(_ dto: VKAlbumDTO, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation?
    func albumEdit(_ dto: VKAlbumDTO, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation?
    func albumDelete(_ vkAlbum: VKAlbum, _ completion: @escaping (ActionResult) -> Void) -> AsyncOperation?
}

class AlbumFormController: UITableViewController {
    enum PrivacyField {
        case view, comment
    }

    weak var delegate: AlbumFormDelegate?
    var vkAlbumToEdit: VKAlbum?

    fileprivate var editablePrivacyField: PrivacyField?
    fileprivate var privacyView: VKPrivacy = VKPrivacy.default
    fileprivate var privacyComment: VKPrivacy = VKPrivacy.default

    @IBOutlet weak var doneButton: UIBarButtonItem! {
        didSet {
            doneButton.isEnabled = false
        }
    }
    @IBOutlet weak var titleTextField: UITextField! {
        didSet {
            titleTextField.addTarget(self, action: #selector(titleDidChange), for: .editingChanged)
        }
    }
    @IBOutlet weak var descriptionTextView: UITextView! {
        didSet {
            descriptionTextView.delegate = self
            descriptionTextView.textContainer.lineFragmentPadding = 0

            placeholderLabel.font = descriptionTextView.font
            placeholderLabel.frame.origin = CGPoint(x: 0, y: (descriptionTextView.font?.pointSize)! / 2)
            placeholderLabel.isHidden = !descriptionTextView.text.isEmpty
        }
    }

    @IBOutlet weak var deleteButtonCell: UITableViewCell!
    @IBOutlet weak var privacyViewSubTitle: UILabel!
    @IBOutlet weak var privacyCommentSubTitle: UILabel!

    private var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Album Description".localized()
        label.textColor = UIColor(white: 0, alpha: 0.22)
        label.numberOfLines = 0
        label.sizeToFit()

        return label
    }()

    @IBAction func doneButtonTap(_ sender: UIBarButtonItem) {
        guard let delegate = self.delegate, let dto = buildDto() else {
            HUD.flash(.error, delay: 1.3); return
        }

        if
            let vkAlbum = vkAlbumToEdit,
            vkAlbum.title == dto.title &&
            vkAlbum.description == dto.description &&
            vkAlbum.getCommentVKPrivacy()?.privacyAccess == dto.commentPrivacy.privacyAccess &&
            vkAlbum.getViewVKPrivacy()?.privacyAccess == dto.viewPrivacy.privacyAccess
        {
            dismiss(animated: true)
            return
        }

        var isShowingHUD = true
        var operation: AsyncOperation?
        let showHUD = { [weak self] (result: ActionResult) in
            isShowingHUD = false

            if result.isCancel || self == nil {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.hide(afterDelay: 0)
                self?.dismiss(animated: true)
                return
            }

            HUD.flash(.error, delay: 1.3)
            // TODO Тут проблема следующая: если указать self?.view то ХУД нарисуется ПОД клавиатурой
            // TODO но если не указать, как выше, худ может нарисоваться уже в другом контроллере
            //HUD.flash(.error, onView: self?.view, delay: 1.3)
        }

        // Редактируем альбом
        if dto.vkAlbum != nil {
            // TODO: Плохо что часть валидации находится где-то здесь...
            guard dto.vkAlbum!.id > 0 else { HUD.flash(.error, delay: 1.3); return }
            operation = delegate.albumEdit(dto, showHUD)
        }
        // Создаем новый альбом
        else {
            operation = delegate.albumCreate(dto, showHUD)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = operation else { return }
            HUD.show(cancelHandler: { operation.cancel() }) // TODO: Ну отмена точно должна быть в менеджере или где-то там
        }
    }

    @IBAction func cancelButtonTap(_ sender: UIBarButtonItem) {
        if
            let title = titleTextField.text, let description = descriptionTextView.text,
            (vkAlbumToEdit != nil && (title != vkAlbumToEdit!.title || description != vkAlbumToEdit!.description)) ||
            (vkAlbumToEdit == nil && (!title.isEmpty || !description.isEmpty))
        {
            let dontSaveAction = UIAlertAction(title: "Don't Save".localized(), style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true)
            }

            let saveActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            saveActionSheet.addAction(dontSaveAction)
            saveActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))

            present(saveActionSheet, animated: true)
            return
        }

        dismiss(animated: true)
    }

    @objc func titleDidChange(_ textField: UITextField) {
        guard let text = textField.text else { return }
        doneButton.isEnabled = text.count >= 2
    }

    fileprivate func buildDto() -> VKAlbumDTO? {
        guard let title = titleTextField.text, title.count >= 2 else { return nil }

        return VKAlbumDTO(
            title,
            descriptionTextView.text,
            vkAlbumToEdit,
            privacyView,
            privacyComment
        )
    }
}

extension AlbumFormController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let vkAlbum = vkAlbumToEdit {
            titleTextField.text = vkAlbum.title
            vkAlbum.description != nil ? descriptionTextView.text = vkAlbum.description : descriptionTextView.addSubview(placeholderLabel)

            privacyView = vkAlbum.getViewVKPrivacy() ?? VKPrivacy.default
            privacyComment = vkAlbum.getCommentVKPrivacy() ?? VKPrivacy.default

            doneButton.isEnabled = vkAlbum.title.count >= 2
            deleteButtonCell.isHidden = false
        } else {
            descriptionTextView.addSubview(placeholderLabel)
        }

        privacyViewSubTitle.text = privacyView.transcript
        privacyCommentSubTitle.text = privacyComment.transcript
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if (titleTextField.text?.isEmpty)! {
            titleTextField.becomeFirstResponder()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        view.endEditing(true)
        navigationItem.backBarButtonItem = UIBarButtonItem()

        guard
            let segueIdentifier = segue.identifier,
            let privacyController = segue.destination as? AlbumPrivacyFormController
            else { return }

        privacyController.delegate = self

        switch segueIdentifier {
        case "showViewPrivacy":
            editablePrivacyField = .view
            privacyController.title = "Who Can View".localized()
            privacyController.selectedVKPrivacy = privacyView

        case "showCommentPrivacy":
            editablePrivacyField = .comment
            privacyController.title = "Who Can Comment".localized()
            privacyController.selectedVKPrivacy = privacyComment

        default: break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let vkAlbum = vkAlbumToEdit,
            let cell = tableView.cellForRow(at: indexPath),
            cell.reuseIdentifier == "deleteButton"
            else { return }

        cell.setSelected(false, animated: true)

        let deleteAction = UIAlertAction(title: "Delete".localized(), style: .destructive) { [weak self] _ in
            var isShowingHUD = true
            let operation = self?.delegate?.albumDelete(vkAlbum) { [weak self] result in
                isShowingHUD = false

                if result.isCancel || self == nil {
                    HUD.hide(); return
                }

                if result.isSuccess {
                    HUD.hide(afterDelay: 0)
                    self?.dismiss(animated: true)
                    return
                }

                HUD.flash(.error, delay: 1.3)
            }

            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                guard isShowingHUD, let operation = operation else { return }
                HUD.show(cancelHandler: { operation.cancel() }) // TODO: Ну отмена точно должна быть в менеджере или где-то там
            }
        }

        let deleteActionSheet = UIAlertController(
            title: "Delete Album".localized(),
            message: "Album and all photos in it will be permanently deleted. This cannot be undone.".localized(),
            preferredStyle: .actionSheet)

        deleteActionSheet.addAction(deleteAction)
        deleteActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))

        present(deleteActionSheet, animated: true)
    }
}

extension AlbumFormController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !descriptionTextView.text.isEmpty
    }
}

extension AlbumFormController: AlbumPrivacyFormDelegate {
    func privacyDidSelect(_ privacy: VKPrivacy) {
        switch editablePrivacyField! {
        case .view:
            privacyViewSubTitle.text = privacy.transcript
            privacyView = privacy
        case .comment:
            privacyCommentSubTitle.text = privacy.transcript
            privacyComment = privacy
        }
    }
}
