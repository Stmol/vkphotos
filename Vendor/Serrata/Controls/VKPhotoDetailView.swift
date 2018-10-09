import UIKit
import VKSdkFramework
import Kingfisher
import RxSwift
import Firebase
import Crashlytics

let VK_RED_HEART_COLOR = UIColor(hex: "FF3347")

struct VKPhotosDetailConst {
    static var textLinesNumbers: Int { return 2 } //TODO return DeviceOrientation.isPortrait ? 2 : 1 }
    static let textVerticalMargin = 4
}

protocol VKPhotoDetailViewDelegate: class {
    var vkPhotosTotalCount: Int { get }

    func tapCancelOperation(_ operation: AsyncOperation)

    func reportVKPhoto(_ vkPhoto: VKPhoto, _ reason: VKPhotoReportReason, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func makeCoverVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func moveVKPhoto(_ vkPhoto: VKPhoto, toVKAlbum: VKAlbum, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func copyVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func editVKPhotoText(_ vkPhoto: VKPhoto, text: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func deleteVKPhoto(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func tapRestoreButton(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?) -> AsyncOperation?
    func tapLikeButton(_ vkPhoto: VKPhoto, completion: ((ActionResult) -> Void)?)
}

public protocol GalleryDelegate: class {
    func close()
    func presentViewController(_ viewController: UIViewController)
}

final class VKPhotoDetailView: UIView {
    fileprivate lazy var shareButton: UIButton = {
        let button = UIButton()
        button.showsTouchWhenHighlighted = true
        button.setImage(#imageLiteral(resourceName: "ev-share-apple"), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        button.addTarget(self, action: #selector(shareButtonTap), for: .touchUpInside)
//        button.imageEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
//        button.backgroundColor = .lightGray

//        button.imageView?.contentMode = .scaleToFill
//        button.contentVerticalAlignment = .center
//        button.contentHorizontalAlignment = .center

        return button
    }()

    fileprivate lazy var menuButton: UIButton = {
        let button = UIButton()
        button.showsTouchWhenHighlighted = true
        button.setImage(#imageLiteral(resourceName: "more-horizontal"), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        button.addTarget(self, action: #selector(menuButtonTap), for: .touchUpInside)

        return button
    }()

    fileprivate lazy var likeButton: UIButton = {
        let button = UIButton()
        button.showsTouchWhenHighlighted = true
        button.setImage(#imageLiteral(resourceName: "like-stroke"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(likeButtonTap), for: .touchUpInside)
        //likeButton.titleLabel?.adjustsFontSizeToFitWidth = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        button.imageEdgeInsets = UIEdgeInsets(top: 15, left: 0, bottom: 15, right: 0)

        return button
    }()

    @IBOutlet weak var toolBar: UIToolbar! {
        didSet {
            toolBar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
            toolBar.setShadowImage(UIImage(), forToolbarPosition: .any)
            toolBar.backgroundColor = .clear
            toolBar.tintColor = .white

            let likeBarItem = UIBarButtonItem(customView: likeButton)
            likeBarItem.customView?.widthAnchor.constraint(lessThanOrEqualToConstant: 120).isActive = true
            likeBarItem.customView?.heightAnchor.constraint(equalToConstant: toolBar.frame.height).isActive = true

            let shareBarItem = UIBarButtonItem(customView: shareButton)
            shareBarItem.customView?.widthAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
            shareBarItem.customView?.heightAnchor.constraint(equalToConstant: toolBar.frame.height).isActive = true

            let menuBarItem = UIBarButtonItem(customView: menuButton)
            menuBarItem.customView?.widthAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
            menuBarItem.customView?.heightAnchor.constraint(equalToConstant: toolBar.frame.height).isActive = true

            toolBar.setItems([
                shareBarItem,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                likeBarItem,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                menuBarItem
            ], animated: false)
        }
    }

    @IBOutlet weak var navigationItem: UINavigationItem!
    @IBOutlet weak var navigationBar: UINavigationBar! {
        didSet {
            navigationBar.setBackgroundImage(UIImage(), for: .default)
            navigationBar.shadowImage = UIImage()
            navigationBar.isTranslucent = true
            navigationBar.backgroundColor = .clear
            navigationBar.barStyle = .black
            navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16, weight: .medium)]
        }
    }

    lazy var restoreButtonView: UIView = {
        let shield = UIView(frame: .zero)
        shield.backgroundColor = .clear
        shield.layer.cornerRadius = 15
        shield.clipsToBounds = true
        shield.isHidden = true

        let button = UIButton()
        button.backgroundColor = .clear
        button.setBackgroundColor(color: UIColor(white: 0, alpha: 0.3), forState: .highlighted)
        button.addTarget(self, action: #selector(restoreButtonViewTap), for: .touchUpInside)

        shield.addSubview(button)
        shield.addConstraints(withFormat: "H:|[v0]|", views: button)
        shield.addConstraints(withFormat: "V:|[v0]|", views: button)

        addSubview(shield)
        shield.widthAnchor.constraint(equalToConstant: 150).isActive = true
        shield.heightAnchor.constraint(equalToConstant: 80).isActive = true
        shield.anchorCenterSuperview()

        return shield
    }()

    @IBOutlet weak var photoInfoView: UIView!
    @IBOutlet weak var dateLabel: UILabel! {
        didSet {
            dateLabel.text = nil
            dateLabel.layer.shadowColor = UIColor.black.cgColor
            dateLabel.layer.shadowRadius = 0.8
            dateLabel.layer.shadowOpacity = 0.4
            dateLabel.layer.masksToBounds = false
            dateLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        }
    }
    @IBOutlet weak var ownerNameLabel: UILabel! {
        didSet {
            ownerNameLabel.text = nil
            ownerNameLabel.layer.shadowColor = UIColor.black.cgColor
            ownerNameLabel.layer.shadowRadius = 1
            ownerNameLabel.layer.shadowOpacity = 0.5
            ownerNameLabel.layer.masksToBounds = false
            ownerNameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
            ownerNameLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleOwnerNameLabelTap)))
        }
    }
    @IBOutlet weak var photoTextGradientView: GradientView!
    @IBOutlet weak var photoTextView: GradientView!
    @IBOutlet weak var photoTextLabel: UILabel! {
        didSet {
            photoTextLabel.layer.shadowColor = UIColor.black.cgColor
            photoTextLabel.layer.shadowRadius = 1
            photoTextLabel.layer.shadowOpacity = 0.5
            photoTextLabel.layer.masksToBounds = false
            photoTextLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        }
    }
    @IBOutlet weak var photoTextScrollView: UIScrollView! {
        didSet {
            photoTextScrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTextTap)))
        }
    }
    @IBOutlet weak var photoTextDim: UIView! {
        didSet {
            photoTextDim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTextTap)))
            photoTextDim.alpha = 0
        }
    }

    @IBOutlet weak var photoTextViewHeightConstraint: NSLayoutConstraint!

    weak var delegate: VKPhotoDetailViewDelegate?
    weak var gallery: GalleryDelegate?

    private var likeTouchSubject = PublishSubject<VKPhoto>()
    private let disposeBag = DisposeBag()

    private var prevPhotoToLike: VKPhoto?
    private var lastVKPhotoId: Int?
    private var vkPhoto: VKPhoto?

    private var truncatedTextHeight: CGFloat = 0
    private var isTextExpanded = false
    private var isReadMoreButtonRequired = false

    private var isFirstAdjusting: Bool { return lastVKPhotoId == nil }

    private var currentPage: Int = 1
    private var totalCount: Int { return delegate?.vkPhotosTotalCount ?? 1 }

    private lazy var textLabelVerticalMarginSum: CGFloat = {
        return CGFloat(VKPhotosDetailConst.textVerticalMargin * 2)
    }()

    private var isPortraitOrientation = true // TODO: Убрать это в viewWillTransition

    override func awakeFromNib() {
        super.awakeFromNib()

        isPortraitOrientation = DeviceOrientation.isPortrait
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRotated),
            name: NSNotification.Name.UIDeviceOrientationDidChange,
            object: nil)

        /// Система просто чума :)
        /// Предотвращает спам лайками, при этом лайкусит все четенько и не забывает про тех кто в очереди
        /// Просто ничего не трогай
        likeTouchSubject.asObserver()
            .do(onNext: { [weak self] vkPhotoToLike in
                guard let this = self else { return }
                if this.prevPhotoToLike != nil && this.prevPhotoToLike != vkPhotoToLike {
                    this.delegate?.tapLikeButton(this.prevPhotoToLike!, completion: nil)
                }

                this.prevPhotoToLike = vkPhotoToLike
            })
            // TODO!! При значении 0.3 фотка обновляется почти сразу что фризит скрол
            .debounce(0.8, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] vkPhoto in
                self?.prevPhotoToLike = nil
                self?.delegate?.tapLikeButton(vkPhoto) { [weak self] result in
                    if (result.isCancel || !result.isSuccess) && vkPhoto == self?.vkPhoto {
                        self?.switchPhotoLikeState()
                    }
                }
            }).disposed(by: disposeBag)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if self == hitView {
            return nil
        }

        return hitView
    }

    @objc func handleOwnerNameLabelTap() {
        guard
            let vkPhoto = vkPhoto,
            let info = vkPhoto.ownerInfo, !info.link.isEmpty
            else { return }

        let actionSheet = UIAlertController.init(title: info.name, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(title: "Cancel".localized(), style: .cancel, isEnabled: true, handler: nil)

        actionSheet.addAction(title: "Open In Browser".localized(), style: .default, isEnabled: true) { _ in
            guard let url = URL(string: info.link) else { return }
            Analytics.logEvent(AnalyticsEvent.PhotoAuthorLookup, parameters: [
                "source": "gallery_ui",
                "url": info.link
            ])

            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }

        if !vkPhoto.isCurrentUserOwner {
            actionSheet.addAction(
                title: vkPhoto.isBanned ? "Unblock User".localized() : "Block User".localized(),
                style: vkPhoto.isBanned ? .default : .destructive,
                isEnabled: true) { _ in
                    let isSuccess = vkPhoto.isBanned
                        ? VKUserBanManager.shared.unban(id: vkPhoto.ownerId)
                        : VKUserBanManager.shared.ban(id: vkPhoto.ownerId)

                    if !isSuccess {
                        HUD.flash(.error, onView: self, delay: 1.3)
                    }
            }
        }

        galleryDelegate?.presentViewController(actionSheet)
    }

    @objc func handleTextTap() {
        if isTextExpanded {
            collapsePhotoText()
        } else if isReadMoreButtonRequired {
            expandPhotoText()
        }
    }

    @objc func onRotated() {
        // TODO!!! Остается кейс когда происходит анимация экспанда/колапса и в этот момент меняется ориентация
        // Короче такие дела: помни что повортов может быть по двум осям
        //                    при том, что ориентация могла не смениться
        //                    событие все равно вызовет этот метод,
        //                    и чтобы не было косяков во время выполнения анимации
        //                    когда устройство меняет ориентацию в пределах той же оси
        //                    надо запоминать в какой ориентации трубка была изначально
        if isPortraitOrientation == DeviceOrientation.isPortrait {
            // То есть режим не сменился, значит ничего не делаем
            return
        } else {
            // Режим поменялся, выполняем регулировку вида и запоминаем факт смены
            isPortraitOrientation = DeviceOrientation.isPortrait
        }

        // Здесь у нас всякие дела с ротацией, можно не лазить, но лучше не забывать
        // Скорее всего, это все надо отправить в `layoutSubviews` (хотя не факт)
        guard let photoText = vkPhoto?.text else { return }
        photoTextLabel.text = photoText

        truncatedTextHeight = photoTextLabel.heightForView(numberOfLines: VKPhotosDetailConst.textLinesNumbers)
        let expandedTextHeight = photoTextLabel.heightForView(numberOfLines: 0)

        isReadMoreButtonRequired = expandedTextHeight > truncatedTextHeight
        if !isTextExpanded && isReadMoreButtonRequired {
            photoTextLabel.numberOfLines = VKPhotosDetailConst.textLinesNumbers
        }

        if !isTextExpanded {
            photoTextViewHeightConstraint.constant = truncatedTextHeight + textLabelVerticalMarginSum
            return
        }

        NSLayoutConstraint.deactivate([photoTextViewHeightConstraint])
        photoTextLabel.numberOfLines = 0

        if isTextExpanded && (expandedTextHeight > photoTextDim.bounds.height) {
            photoTextViewHeightConstraint = photoTextView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
            photoTextViewHeightConstraint.isActive = true
            photoTextScrollView.isScrollEnabled = true
        } else {
            photoTextViewHeightConstraint = photoTextView.heightAnchor.constraint(equalToConstant: expandedTextHeight + textLabelVerticalMarginSum)
            photoTextViewHeightConstraint.isActive = true
            photoTextScrollView.isScrollEnabled = false
        }
    }

    @objc func restoreButtonViewTap(_ sender: UIButton) {
        Analytics.logEvent(AnalyticsEvent.PhotoRestore, parameters: ["source": "gallery_ui"])
        restorePhoto()
    }

    @objc func shareButtonTap(_ sender: UIBarButtonItem) {
        if isTextExpanded { collapsePhotoText() }
        sharePhoto()
    }

    @objc func likeButtonTap(_ sender: UIBarButtonItem) {
        switchPhotoLikeState()
        likeTouchSubject.onNext(self.vkPhoto!)

        Analytics.logEvent(
            vkPhoto!.isLiked ? AnalyticsEvent.PhotoLike : AnalyticsEvent.PhotoDislike,
            parameters: ["source": "gallery_ui"]
        )
    }

    @objc func menuButtonTap(_ sender: UIBarButtonItem) {
        guard let vkPhoto = vkPhoto else { return }

        if isTextExpanded { collapsePhotoText() }

        let copyAction = UIAlertAction(title: "Add to Saved".localized(), style: .default) { [weak self] _ in
            self?.copyPhoto()
        }

        let moveAction = UIAlertAction(title: "Move to Album".localized(), style: .default) { [weak self] _ in
            guard let vkPhoto = self?.vkPhoto, !vkPhoto.isDeleted else { return }

            if let controller = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "VKAlbumsTable") as? VKAlbumsTableController {

                controller.isSystemAlbumsExcluded = true
                controller.excludedVKAlbumIds = [vkPhoto.albumId]
                controller.onVKAlbumSelected = { [weak self] vkAlbum in
                    self?.movePhoto(to: vkAlbum)
                }

                self?.gallery?.presentViewController(controller)
            }
        }

        let editAction = UIAlertAction(title: "Edit Caption".localized(), style: .default) { [weak self] _ in
            guard let vkPhoto = self?.vkPhoto, !vkPhoto.isDeleted else { return }

            // TODO: Переименовать PhotosUploadEditDetailsController
            if let photoDetailController = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "PhotoEditTextController") as? PhotosUploadEditDetailsController {
                photoDetailController.vkPhoto = vkPhoto
                photoDetailController.delegate = self

                self?.gallery?.presentViewController(photoDetailController)
            }
        }

        let makeCoverAction = UIAlertAction(title: "Set as Album Cover".localized(), style: .default) { [weak self] _ in
            self?.makeCover()
        }

        let deleteAction = UIAlertAction(title: "Delete".localized(), style: .destructive) { [weak self] _ in
            self?.deletePhoto()
        }

        let restoreAction = UIAlertAction(title: "Recover".localized(), style: .default) { [weak self] _ in
            Analytics.logEvent(AnalyticsEvent.PhotoRestore, parameters: ["source": "gallery_action_sheet"])
            self?.restorePhoto()
        }

        let reportAction = UIAlertAction(title: "Report Photo".localized(), style: .destructive) { [weak self] _ in
            let reportActionSheet = UIAlertController(title: "Report reason".localized(), message: nil, preferredStyle: .actionSheet)
            reportActionSheet.addAction(title: "It's spam".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.spam) }
            reportActionSheet.addAction(title: "Verbal abuse".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.offense) }
            reportActionSheet.addAction(title: "Adult content".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.adult) }
            reportActionSheet.addAction(title: "Drug advocacy".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.drugs) }
            reportActionSheet.addAction(title: "Child pornography".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.childPron) }
            reportActionSheet.addAction(title: "Violence".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.violence) }
            reportActionSheet.addAction(title: "Extremism".localized(), style: .default, isEnabled: true) { [weak self] _ in self?.reportPhoto(.extremism) }
            reportActionSheet.addAction(title: "Cancel".localized(), style: .cancel, isEnabled: true)

            self?.gallery?.presentViewController(reportActionSheet)
        }

        restoreAction.isEnabled = vkPhoto.isCurrentUserOwner
        deleteAction.isEnabled = vkPhoto.isCurrentUserOwner

        makeCoverAction.isEnabled = vkPhoto.isCurrentUserOwner && !vkPhoto.isDeleted
        moveAction.isEnabled = vkPhoto.isCurrentUserOwner && !vkPhoto.isDeleted
        editAction.isEnabled = vkPhoto.isCurrentUserOwner && !vkPhoto.isDeleted
        copyAction.isEnabled = !vkPhoto.isDeleted && !vkPhoto.isBanned
        reportAction.isEnabled = !vkPhoto.isDeleted && !vkPhoto.isBanned

        let menuActionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menuActionSheet.addAction(copyAction)

        if vkPhoto.isCurrentUserOwner {
            if vkPhoto.albumId > 0 {
                menuActionSheet.addAction(makeCoverAction)
            }

            if vkPhoto.albumId != -6 {
                // Нельзя переносить фотки из альбома "Фото с моей страницы"
                menuActionSheet.addAction(moveAction)
            }

            if vkPhoto.isEditableCaption {
                // Нельзя менять описания у фоток из альбомов Сохранок и С моей страницы
                menuActionSheet.addAction(editAction)
            }

            menuActionSheet.addAction(vkPhoto.isDeleted ? restoreAction : deleteAction)
        } else {
            menuActionSheet.addAction(reportAction)
        }

        menuActionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel))
        gallery?.presentViewController(menuActionSheet)
    }

    @IBAction private func tapCloseButton(_ sender: UIBarButtonItem) {
        gallery?.close()
    }

    func updateTitleCounter() {
        navigationItem.title = "\(currentPage) " + "of".localized() + " \(totalCount)"
    }

    private func setupTextLabel() {
        if vkPhoto == nil || vkPhoto!.text.isEmpty {
            photoTextLabel.text = nil
            photoTextView.isHidden = true
            photoTextGradientView.alpha = 0

            return
        }

        isReadMoreButtonRequired = false
        isTextExpanded = false
        photoTextDim.alpha = 0
        photoTextGradientView.alpha = 1

        photoTextLabel.text = vkPhoto!.text.trimmingCharacters(in: .whitespacesAndNewlines)
        truncatedTextHeight = photoTextLabel.heightForView(numberOfLines: VKPhotosDetailConst.textLinesNumbers)

        if photoTextLabel.heightForView(numberOfLines: 0) > truncatedTextHeight {
            isReadMoreButtonRequired = true
            photoTextLabel.numberOfLines = VKPhotosDetailConst.textLinesNumbers
        }

        NSLayoutConstraint.deactivate([photoTextViewHeightConstraint])
        photoTextViewHeightConstraint = photoTextView.heightAnchor.constraint(equalToConstant: truncatedTextHeight + textLabelVerticalMarginSum)
        photoTextViewHeightConstraint.isActive = true

        photoTextView.isHidden = false
    }

    private func setupInfo() {
        dateLabel.text = nil
        ownerNameLabel.text = nil

        guard let vkPhoto = vkPhoto else { return }

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.locale = NSLocale.current
        formatter.dateFormat = "dd MMM yyyy"

        let date = Date(timeIntervalSince1970: Double(vkPhoto.date))
        dateLabel.text = formatter.string(from: date)

        if vkPhoto.isInfoExist, let ownerInfo = vkPhoto.ownerInfo {
            ownerNameLabel.text = ownerInfo.name.isEmpty ? " " : "\(ownerInfo.name)"
            return
        }

        // Мы попали сюда, а инфы о фотке нет :( надо попросить ее у старшего
        // if !isFirstAdjusting {
        // update: сейчас инфа о фотках автоподгружается,
        // поэтому при первом запуске галерии запрашивать инфу не надо
        // TODO: но он запрашивает ее при `reloadData` и `reloadPhoto` !!!
        // delegate?.needVKPhotoInfo(vkPhoto, completion: nil)
        // }
    }

    private func updateLikeButton() {
        guard let vkPhoto = vkPhoto, vkPhoto.likes != nil else {
            likeButton.isEnabled = false
            likeButton.setAttributedTitle(nil, for: .normal)
            likeButton.tintColor = .white
            return
        }

        likeButton.isEnabled = !vkPhoto.isDeleted
        likeButton.tintColor = vkPhoto.isLiked ? VK_RED_HEART_COLOR : .white

        vkPhoto.isLiked ? likeButton.setImage(#imageLiteral(resourceName: "like-filled"), for: .normal) : likeButton.setImage(#imageLiteral(resourceName: "like-stroke"), for: .normal)

        if vkPhoto.likes!.count == 0 {
            likeButton.setAttributedTitle(nil, for: .normal)
            return
        }

        let textAttributes = [
            // UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 15, weight: .medium),
            NSAttributedStringKey.foregroundColor: vkPhoto.isLiked ? VK_RED_HEART_COLOR : .white
        ]

        let countString = NSAttributedString(
            string: " \(vkPhoto.likes!.count.formatUsingAbbrevation())",
            attributes: textAttributes)
        likeButton.setAttributedTitle(countString, for: .normal)
    }

    private func switchPhotoLikeState() {
        guard let vkPhoto = vkPhoto, let likes = vkPhoto.likes else { return }

        self.vkPhoto!.likes!.userLikes = likes.isLiked ? 0 : 1
        self.vkPhoto!.likes!.count = likes.isLiked
            ? (likes.count - 1 < 0 ? 0 : likes.count - 1 )
            : likes.count + 1

        updateLikeButton()
    }

    private func expandPhotoText() {
        guard let vkPhoto = vkPhoto, isTextExpanded == false else { return }
        Analytics.logEvent(AnalyticsEvent.PhotoTextLookup, parameters: ["source": "gallery_ui"])

        restoreButtonView.alpha = 0
        photoTextLabel.text = vkPhoto.text

        let expandedTextHeight = photoTextLabel.heightForView(numberOfLines: 0) + textLabelVerticalMarginSum

        NSLayoutConstraint.deactivate([photoTextViewHeightConstraint])
        if expandedTextHeight >= photoTextDim.bounds.height {
            photoTextViewHeightConstraint = photoTextView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor)
            photoTextScrollView.isScrollEnabled = true
        } else {
            photoTextViewHeightConstraint = photoTextView.heightAnchor.constraint(equalToConstant: expandedTextHeight)
        }

        photoTextViewHeightConstraint.priority = .defaultLow
        photoTextViewHeightConstraint.isActive = true

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.6,
            options: [.curveEaseInOut],
            animations: { [weak self] in
                self?.photoTextLabel.numberOfLines = 0
                self?.photoTextDim.alpha = 1
                self?.photoTextGradientView.alpha = 0
                self?.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.isTextExpanded = true
        })
    }

    private func collapsePhotoText() {
        guard vkPhoto != nil, isTextExpanded else { return }

        restoreButtonView.alpha = 1
        photoTextScrollView.setContentOffset(CGPoint(x: photoTextScrollView.contentOffset.x, y: -photoTextScrollView.contentInset.top), animated: false)
        photoTextScrollView.isScrollEnabled = false

        NSLayoutConstraint.deactivate([photoTextViewHeightConstraint])
        photoTextViewHeightConstraint = photoTextView.heightAnchor.constraint(equalToConstant: truncatedTextHeight + textLabelVerticalMarginSum)
        photoTextViewHeightConstraint.isActive = true

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.6,
            options: [.curveEaseInOut],
            animations: { [weak self] in
                self?.photoTextDim.alpha = 0
                self?.photoTextGradientView.alpha = 1
                self?.layoutIfNeeded()
        }) { [weak self] _ in
            guard let this = self else { return }
            self?.photoTextLabel.numberOfLines = VKPhotosDetailConst.textLinesNumbers
            this.isTextExpanded = false
        }
    }

    private func sharePhoto() {
        guard
            let vkPhoto = vkPhoto,
            !vkPhoto.isDeleted && !vkPhoto.isBanned,
            let url = vkPhoto.getVKSize(byType: "w")?.getUrl() else {
            HUD.flash(.error, onView: self, delay: 1.3); return
        }

        var isShowingHUD = true

        // TODO: Плохо что пользователь видит прелоадер вначале а не активити контроллер
        ImageDownloader.default.downloadImage(with: URL(string: url)!) { [weak self] image, _, _, _ in
            isShowingHUD = false
            guard let this = self, let photo = image else {
                HUD.flash(.error, onView: self, delay: 1.3); return
            }

            HUD.hide(afterDelay: 0)
            let activity = UIActivityViewController(activityItems: [photo], applicationActivities: nil)
            activity.completionWithItemsHandler = { activityType, result, _, error in
                guard let activityType = activityType, result == true else { return }

                if error != nil {
                    Crashlytics.sharedInstance().recordError(error!)
                    HUD.flash(.error, onView: self, delay: 1.3); return
                }

                Analytics.logEvent(AnalyticsEvent.PhotoShare, parameters: [
                    "source": "gallery_ui",
                    "activity_type": activityType.rawValue
                ])

                switch activityType {
                case .saveToCameraRoll, .copyToPasteboard:
                    HUD.flash(.success, onView: self, delay: 0.5) { _ in
                        if activityType == .copyToPasteboard { return }
                        StoreReviewHelper.checkAndAskForReview()
                    }
                default: break
                }
            }

            this.gallery?.presentViewController(activity)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            if !isShowingHUD { return }
            HUD.show(cancelHandler: { ImageDownloader.default.cancelAll() }, onView: self)
        }
    }

    private func restorePhoto() {
        guard let vkPhoto = vkPhoto else { return }
        var isShowingHUD = true

        let restoreOperation = delegate?.tapRestoreButton(vkPhoto) { [weak self] result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                self?.restoreButtonView.isHidden = true
                HUD.hide(afterDelay: 0)
                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = restoreOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }
    }

    private func deletePhoto() {
        guard let vkPhoto = vkPhoto, !vkPhoto.isDeleted else { return }
        var isShowingHUD = true

        let deleteOperation = delegate?.deleteVKPhoto(vkPhoto) { [weak self] result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                self?.restoreButtonView.isHidden = false
                HUD.hide(afterDelay: 0)
                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = deleteOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }

        Analytics.logEvent(AnalyticsEvent.PhotoDelete, parameters: ["source": "gallery_action_sheet"])
    }

    private func copyPhoto() {
        guard let vkPhoto = vkPhoto, !vkPhoto.isDeleted else { return }
        var isShowingHUD = true

        let copyOperation = delegate?.copyVKPhoto(vkPhoto) { result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.flash(.success, onView: self, delay: 0.5) { _ in
                    StoreReviewHelper.checkAndAskForReview()
                }

                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = copyOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }

        Analytics.logEvent(AnalyticsEvent.PhotoCopyToSaves, parameters: ["source": "gallery_action_sheet"])
    }

    private func makeCover() {
        guard let vkPhoto = vkPhoto, !vkPhoto.isDeleted else { return }
        var isShowingHUD = true

        let coverOperation = delegate?.makeCoverVKPhoto(vkPhoto) { result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.flash(.success, onView: self, delay: 0.5) { _ in
                    StoreReviewHelper.checkAndAskForReview()
                }

                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = coverOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }

        Analytics.logEvent(AnalyticsEvent.PhotoMakeCover, parameters: ["source": "gallery_action_sheet"])
    }

    private func movePhoto(to album: VKAlbum) {
        guard let vkPhoto = self.vkPhoto, !vkPhoto.isDeleted else { return }
        var isShowingHUD = true

        let moveOperation = delegate?.moveVKPhoto(vkPhoto, toVKAlbum: album) { result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.flash(.success, onView: self, delay: 0.5) { _ in
                    StoreReviewHelper.checkAndAskForReview()
                }

                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = moveOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }

        Analytics.logEvent(AnalyticsEvent.PhotoMoveToAlbum, parameters: ["source": "gallery_action_sheet"])
    }

    private func reportPhoto(_ reason: VKPhotoReportReason) {
        guard let vkPhoto = vkPhoto else { return }
        var isShowingHUD = true

        let reportOperation = delegate?.reportVKPhoto(vkPhoto, reason) { result in
            isShowingHUD = false

            if result.isCancel {
                HUD.hide(); return
            }

            if result.isSuccess {
                HUD.flash(.success, onView: self, delay: 0.5)
                return
            }

            HUD.flash(.error, onView: self, delay: 1.3)
        }

        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            guard isShowingHUD, let operation = reportOperation else { return }
            HUD.show(cancelHandler: { [weak self] in
                self?.delegate?.tapCancelOperation(operation)
            }, onView: self)
        }

        Analytics.logEvent(AnalyticsEvent.PhotoReport, parameters: [
            "source": "gallery_action_sheet",
            "photo": "\(vkPhoto.ownerId)_\(vkPhoto.id)",
            "reason": "\(reason.rawValue)"
        ])
    }
    // Транкейтит текст и добаляет кнопку "Read more"
    //    private func addReadMoreButtonToPhotoText() {
    //        DispatchQueue.main.async { [weak self] in
    //            self?.photoTextLabel.addTrailing(
    //                "... ",
    //                numberOfLines: VKPhotosDetailConst.textLinesNumbers,
    //                moreText: "Раскрыть",
    //                moreTextFont: UIFont.systemFont(ofSize: 15),
    //                moreTextColor: UIColor(red: 154/255, green: 154/255, blue: 154/255, alpha: 0.9))
    //        }
    //    }
}

extension VKPhotoDetailView: AdjustableDetailsViewDelegate {
    var galleryDelegate: GalleryDelegate? {
        get { return gallery }
        set { gallery = newValue }
    }

    var bottomViewHeight: CGFloat {
        // TODO: Надо куда-то деть прогрес-кольцо подгрузки хай реза при развернутом тексте
        return toolBar.frame.height + photoTextView.frame.height + photoInfoView.frame.height
    }

    func adjustToPhoto(_ vkPhoto: VKPhoto, with pageIndex: Int) {
        self.vkPhoto = vkPhoto
        self.currentPage = pageIndex + 1

        updateTitleCounter()
        setupInfo()
        updateLikeButton()

        if lastVKPhotoId == nil || (lastVKPhotoId != nil && lastVKPhotoId! != vkPhoto.id ) {
            // Обновляем текст к фотке, только в случае смены самой фотки
            setupTextLabel()
        }

        shareButton.isEnabled = !vkPhoto.isDeleted
        restoreButtonView.isHidden = !vkPhoto.isDeleted

        lastVKPhotoId = vkPhoto.id
    }

    func beforeGalleryClose() {
        if let prevPhotoToLike = prevPhotoToLike {
            delegate?.tapLikeButton(prevPhotoToLike, completion: nil)
        }
    }
}

extension VKPhotoDetailView: PhotoCaptionEditingProtocol {
    func onCaptionSave(_ vkPhoto: VKPhoto, caption: String, completion: ((ActionResult) -> Void)?) -> AsyncOperation? {
        Analytics.logEvent(AnalyticsEvent.PhotoEditCaption, parameters: ["source": "gallery_action_sheet"])

        return delegate?.editVKPhotoText(vkPhoto, text: caption) { [weak self] result in
            if result.isSuccess { self?.setupTextLabel() }
            completion?(result)
        }
    }
}
