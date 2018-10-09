//
//  SlideLeafCell.swift
//  Serrata
//

import UIKit
import Kingfisher
import UICircularProgressRing

public protocol SlideLeafCellDelegate: class {
    func slideLeafScrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?)
    func slideLeafScrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat)
    func longPressImageView()
}

class SlideLeafCell: UICollectionViewCell {

    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.maximumZoomScale = 3
            scrollView.minimumZoomScale = 1
            scrollView.delegate = self
        }
    }
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var zoomImageProgressRing: UICircularProgressRingView!
    @IBOutlet weak var zoomImageProgressRingBottomConstraint: NSLayoutConstraint!

    var zoomTapGesture: UITapGestureRecognizer!
    weak var delegate: SlideLeafCellDelegate?

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = true

        return imageView
    }()

    /**
     Табличка поверх фотки с кнопкой восстановить фото, после удаления
    */
    lazy var restoreView: UIView = {
        let shield = UIView(frame: .zero)
        shield.backgroundColor = .clear
        shield.clipsToBounds = true
        shield.layer.cornerRadius = 15

        shield.isHidden = true
        shield.alpha = 0

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.addSubview(blurView)

        let label = UILabel()
        label.text = "Recover".localized()
        label.textAlignment = .center
        label.textColor = .white

        shield.addSubview(label)
        label.anchorCenterSuperview()

        imageView.addSubview(shield)
        shield.widthAnchor.constraint(equalToConstant: 150).isActive = true
        shield.heightAnchor.constraint(equalToConstant: 80).isActive = true
        shield.anchorCenterSuperview()

        return shield
    }()

    /**
     Табличка поверх фотки с инфой о заблокированном пользователе
    */
    lazy var banInfoView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.layer.cornerRadius = 15

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)

        let info = UILabel()
        info.text = "Blocked User Info".localized()
        info.textColor = .white
        info.textAlignment = .left
        info.numberOfLines = 0
        info.font = .systemFont(ofSize: 14)

        let button = UIButton()
        button.addTarget(self, action: #selector(onUnblockUserButtonTap), for: .touchUpInside)
        button.setBackgroundColor(color: UIColor(white: 1, alpha: 0.5), forState: .highlighted)
        button.setTitle("Unblock User".localized(), for: .normal)

        view.autoresizingMask = [.flexibleHeight]
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubviews([info, button])
        view.addConstraints(withFormat: "V:|-15-[v0][v1(45)]|", views: info, button)
        view.addConstraints(withFormat: "H:|-15-[v0]-15-|", views: info)
        view.addConstraints(withFormat: "H:|[v0]|", views: button)

        var line = UIView(frame: .zero)
        line.backgroundColor = .darkGray
        button.addSubview(line)
        button.addConstraints(withFormat: "V:|[v0(1)]", views: line)
        button.addConstraints(withFormat: "H:|[v0]|", views: line)

        return view
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        zoomTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        zoomTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(zoomTapGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressGesture(_:)))
        imageView.addGestureRecognizer(longPressGesture)
    }

    override func prepareForReuse() {
        imageView.kf.cancelDownloadTask()

        restoreView.isHidden = true
        restoreView.alpha = 0

        banInfoView.removeFromSuperview()

        activityIndicatorView.isHidden = false
        zoomImageProgressRing.isHidden = true
        zoomImageProgressRing.setProgress(to: 0, duration: 0)

        imageView.image = nil
        scrollView.setZoomScale(1, animated: false)
    }

//    override func layoutSubviews() {
//        super.layoutSubviews()
//
//        if let image = imageView.image {
//            scrollView.setZoomScale(1, animated: false)
//            calcImageViewFrame(image)
//            banInfoView.setNeedsUpdateConstraints()
//        }
//    }

    var vkPhoto: VKPhoto? = nil {
        didSet { configure() }
    }

    // MARK: Initialize and start download images -
    func configure() {
        guard
            let previewPhotoUrl = getPreviewPhotoUrl(),
            let hqPhotoUrl = getHQPhotoUrl(),
            let vkPhoto = self.vkPhoto
            else { return } // TODO: И что return? Что будет в ячейке вместо фото?

        scrollView.bounces = !vkPhoto.isDeleted
        scrollView.bouncesZoom = !vkPhoto.isDeleted
        scrollView.maximumZoomScale = vkPhoto.isDeleted ? 1 : 3

        let previewUrl = URL(string: previewPhotoUrl)
        let hqUrl = URL(string: hqPhotoUrl)

        var options: KingfisherOptionsInfo = []
        if vkPhoto.isBanned {
            options.append(.processor(BlurImageProcessor(blurRadius: 30)))
        }

        imageView.kf.setImage(with: previewUrl, options: options) { [weak self] image, _, _, imageUrl in
            // TODO: if error -> show reload button
            guard
                let image = image,
                let imageUrl = imageUrl,
                imageUrl.absoluteString == self?.getPreviewPhotoUrl()
            else { return }

            self?.activityIndicatorView.isHidden = true
            self?.setImage(image)

            if vkPhoto.isBanned { return }
            var options: KingfisherOptionsInfo = []

            if vkPhoto.isDeleted {
                self?.restoreView.isHidden = false
                options.append(.processor(BlackWhiteProcessor()))
                options.append(.transition(.fade(0.3)))
            }

            self?.imageView.kf.setImage(with: hqUrl, placeholder: image, options: options)
        }
    }

    func onDismissAnimationDidStart() {
        if let vkPhoto = vkPhoto, vkPhoto.isBanned {
            banInfoView.alpha = 0
        }
    }

    func onDismissAnimationDidEnd() {
        if let vkPhoto = vkPhoto, vkPhoto.isBanned {
            banInfoView.alpha = 1
        }
    }

    private func setImage(_ image: UIImage) {
        calcImageViewFrame(image)
        scrollView.addSubview(imageView)

        if let vkPhoto = vkPhoto, vkPhoto.isBanned {
            addBanInfoView()
        }
    }

    private func calcImageViewFrame(_ image: UIImage) {
        let imageHeight = image.size.height
        let imageWidth = image.size.width
        let screenSize = UIScreen.main.bounds.size
        let hRate = screenSize.height / imageHeight
        let wRate = screenSize.width / imageWidth
        let rate = min(hRate, wRate)
        let imageViewSize = CGSize(width: floor(imageWidth * rate), height: floor(imageHeight * rate))

        imageView.frame.size = imageViewSize
        scrollView.contentSize = imageViewSize
        updateImageViewToCenter()
    }

    private func updateImageViewToCenter() {
        let screenSize = UIScreen.main.bounds.size
        let heightMargin = (screenSize.height - imageView.frame.height) / 2
        let widthMargin = (screenSize.width - imageView.frame.width) / 2
        scrollView.contentInset = UIEdgeInsets(top: max(heightMargin, 0),
                                               left: max(widthMargin, 0),
                                               bottom: 0,
                                               right: 0)
    }

    private func addBanInfoView() {
        addSubview(banInfoView)
        banInfoView.anchorCenterYToSuperview()
        addConstraints(withFormat: "H:|-15-[v0]-15-|", views: banInfoView)
    }

    @objc func onUnblockUserButtonTap(_ sender: UIButton) {
        guard
            let ownerId = vkPhoto?.ownerId,
            VKUserBanManager.shared.isBanned(id: ownerId)
            else { return }

        let _ = VKUserBanManager.shared.unban(id: ownerId)
    }

    @objc public func handleDoubleTapGesture(_ sender: UITapGestureRecognizer) {
        if vkPhoto!.isDeleted || vkPhoto!.isBanned {
            imageView.shakeAnimation()
            return
        }

        if scrollView.maximumZoomScale > scrollView.zoomScale {
            let location = sender.location(in: imageView)
            let zoomRect = CGRect(origin: location, size: .zero)
            scrollView.zoom(to: zoomRect, animated: true)
            updateImageViewToCenter()
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }

    @objc private func longPressGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            delegate?.longPressImageView()
        }
    }
}

extension SlideLeafCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateImageViewToCenter()
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        delegate?.slideLeafScrollViewWillBeginZooming(scrollView, with: view)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale > 1 {
            loadImageForZoom()
        }

        delegate?.slideLeafScrollViewDidEndZooming(scrollView, with: view, atScale: scale)
    }
}

extension SlideLeafCell {
    private func getPreviewPhotoUrl() -> String? {
        return vkPhoto?.getVKSize(byType: "x")?.getUrl()
    }

    private func getHQPhotoUrl() -> String? {
        return vkPhoto?.getVKSize(byType: "y")?.getUrl()
    }

    private func getZoomPhotoUrl() -> String? {
        return vkPhoto?.getVKSize(byType: "w")?.getUrl()
    }

    private func loadImageForZoom() {
        guard let zoomPhotoUrl = getZoomPhotoUrl() else { return }

        zoomImageProgressRing.isHidden = false
        zoomImageProgressRing.setProgress(to: 0, duration: 0)

        imageView.kf.setImage(
            with: URL(string: zoomPhotoUrl),
            placeholder: imageView.image,
            progressBlock: { [weak self] receivedSize, totalSize in
                guard zoomPhotoUrl == self?.getZoomPhotoUrl() else { return }

                let percentage = CGFloat(receivedSize) / CGFloat(totalSize)
                if percentage < 0.95 {
                    self?.zoomImageProgressRing.setProgress(to: percentage, duration: 0.3)
                }
            },
            completionHandler: { [weak self] _, _, _, imageUrl in
                guard let imageUrl = imageUrl, imageUrl.absoluteString == self?.getZoomPhotoUrl() else { return }

                if self?.zoomImageProgressRing.currentValue == 0 {
                    self?.zoomImageProgressRing.isHidden = true

                    return
                }

                self?.zoomImageProgressRing.setProgress(to: 1, duration: 0.1) {
                    self?.zoomImageProgressRing.isHidden = true
                }
            }
        )
    }
}
