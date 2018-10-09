//
//  SlideLeafViewController.swift
//  Serrata
//
//  Created by Takuma Horiuchi on 2017/11/29.
//  Copyright © 2017年 Takuma Horiuchi. All rights reserved.
//

import UIKit
import Kingfisher
import VKSdkFramework
import DeepDiff

fileprivate enum SlideLeafConst {
    static let minimumLineSpacing: CGFloat = 20
    static let cellBothEndSpacing: CGFloat = minimumLineSpacing / 2
}

protocol AdjustableDetailsViewDelegate: class {
    var galleryDelegate: GalleryDelegate? { get set }
    var bottomViewHeight: CGFloat { get }

    func adjustToPhoto(_ vkPhoto: VKPhoto, with currentPageIndex: Int)
    func beforeGalleryClose()
}

protocol SlideLeafViewControllerDelegate: class {
    func photoDidDisplayed(atIndex: Int)
    func longPressImageView(slideLeafViewController: SlideLeafViewController, photo: VKPhoto, pageIndex: Int)
    func browserDismissed(photo: VKPhoto, pageIndex: Int)
}

class SlideLeafViewController: UIViewController {

    override var prefersStatusBarHidden: Bool {
        return DeviceOrientation.isLandscape ? true : isStatusBarHidden
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var shouldAutorotate: Bool { return isShouldAutorotate }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { return .fade }

    override func prefersHomeIndicatorAutoHidden() -> Bool { return false }

    @IBOutlet private var singleTapGesture: UITapGestureRecognizer!

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.register(UINib(nibName: "SlideLeafCell", bundle: Bundle(for: SlideLeaf.self)), forCellWithReuseIdentifier: "SlideLeafCell")
            collectionView.delegate = self
            collectionView.dataSource = self
            collectionView.prefetchDataSource = self

//            if #available(iOS 11.0, *) {
//                collectionView.contentInsetAdjustmentBehavior = .never
//            }
        }
    }

    @IBOutlet weak private var collectionViewLeadingConstraint: NSLayoutConstraint! { // default = 0
        didSet {
            collectionViewLeadingConstraint.constant = -SlideLeafConst.cellBothEndSpacing
        }
    }

    @IBOutlet weak private var collectionViewTrailingConstraint: NSLayoutConstraint! { // default = 0
        didSet {
            collectionViewTrailingConstraint.constant = SlideLeafConst.cellBothEndSpacing
        }
    }

    @IBOutlet weak private var flowLayout: UICollectionViewFlowLayout! {
        didSet {
            flowLayout.scrollDirection = .horizontal
            flowLayout.sectionInset = UIEdgeInsets(top: 0,
                                                   left: SlideLeafConst.cellBothEndSpacing,
                                                   bottom: 0,
                                                   right: SlideLeafConst.cellBothEndSpacing)
            flowLayout.minimumLineSpacing = SlideLeafConst.minimumLineSpacing
            flowLayout.minimumInteritemSpacing = 0
        }
    }

    @IBOutlet weak private var rotationBlackImageView: UIImageView! {
        didSet {
            rotationBlackImageView.contentMode = .scaleAspectFit
            rotationBlackImageView.backgroundColor = .black
        }
    }

    weak var photoDetailView: (UIView & AdjustableDetailsViewDelegate)? {
        didSet {
            guard photoDetailView != nil else { return }
            photoDetailView!.galleryDelegate = self

            view.addSubview(photoDetailView!)
            view.addConstraints(withFormat: "H:|[v0]|", views: photoDetailView!)
            view.addConstraints(withFormat: "V:|[v0]|", views: photoDetailView!)
        }
    }

    @IBOutlet weak var gesturesContainerView: UIView!

    lazy private var firstSetImageDetail: (() -> ())? = {
        guard pageIndex <= photos.count else { return nil }
        //photoDetailView?.adjustToPhoto(photos[pageIndex], with: pageIndex)
        setPageIndexOffSet(pageIndex)
        return nil
    }()

    // MARK: Delegates -
    weak var delegate: SlideLeafViewControllerDelegate?

    // MARK: Serrata -
    private var serrataTransition = SerrataTransition()

    private var isShouldAutorotate = true
    private var isPrefersHomeIndicatorAutoHidden = false

    private var originPanImageViewCenterY: CGFloat = 0
    private var panImageViewCenterY: CGFloat = 0
    private var selectedCell = SlideLeafCell()
    private var isDecideDismiss = false

    // MARK: Yury Smidovich -
    var willDisplayPhotoAt: ((Int, Int) -> Void)? = nil

    private(set) var photos = [VKPhoto]()
    private var isStatusBarHidden = false
    private var isAppearanceVisible = true
    private var isUnderAnimation = false { // Происходит анимация галереи, например закрытие
        didSet {
            if oldValue == true && isUnderAnimation == false {
                adjustPhotoPlease?(); adjustPhotoPlease = nil
            }
        }
    }

    // Сюда попадает блок аджаста если он был задержан происходящей анимацией
    private var adjustPhotoPlease: (() -> Void)? = nil

    // Текущий индекс фото
    private var pageIndex = 0 {
        didSet {
            if photoDetailView != nil && pageIndex != oldValue && pageIndex <= photos.count {
                photoDetailView?.adjustToPhoto(photos[pageIndex], with: pageIndex)
            }
        }
    }

    // MARK: Init -
    /// This method generates SlideLeafViewController.
    ///
    /// - Returns: Instance of SlideLeafViewController.
    class func make(
        photos: [VKPhoto],
        startPageIndex: Int = 0,
        fromImageView: UIImageView? = nil,
        photoDetailView: (UIView & AdjustableDetailsViewDelegate)? = nil
    ) -> SlideLeafViewController {
        let viewController = UIStoryboard(
            name: "SlideLeafViewController",
            bundle: Bundle(for: SlideLeafViewController.self)
        ).instantiateViewController(withIdentifier: "SlideLeafViewController") as! SlideLeafViewController

        if photoDetailView != nil {
            viewController.photoDetailView = photoDetailView!
        }

        viewController.photos = photos
        viewController.pageIndex = photos.count == 1 ? 0 : startPageIndex

        viewController.transitioningDelegate = viewController.serrataTransition
        viewController.serrataTransition.setFromImageView(fromImageView)

        return viewController
    }

    // MARK: Controller lifecycle -
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !photos.isEmpty && pageIndex <= photos.count {
            photoDetailView?.adjustToPhoto(photos[pageIndex], with: pageIndex)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        firstSetImageDetail?()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // TODO: freezePageIndex is a fix for fast scrolling in landscape mode + rotation from some vertical images
        let freezePageIndex = pageIndex

        let indexPath = IndexPath(row: pageIndex, section: 0)
        if
            let cell = collectionView.cellForItem(at: indexPath) as? SlideLeafCell,
            let image = cell.imageView.image {
                rotationBlackImageView.image = image
                collectionView.isHidden = true

                coordinator.animate(alongsideTransition: { _ in
                    self.setPageIndexOffSet(freezePageIndex)
                }) { _ in
                    self.collectionView.reloadData()
                    self.rotationBlackImageView.image = nil
                    self.collectionView.isHidden = false
                }
            }
    }

    // MARK: Handlers -
    @IBAction private func handleTapGesture(_ sender: UITapGestureRecognizer) {
        isAppearanceVisible ? hideAppearance() : showAppearance()
    }

    @IBAction private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            isUnderAnimation = true
            isShouldAutorotate = false
            hideAppearance()

            let point = sender.location(in: collectionView)
            if
                let indexPath = collectionView.indexPathForItem(at: point),
                let cell = collectionView.cellForItem(at: indexPath) as? SlideLeafCell {
                    selectedCell = cell
                    originPanImageViewCenterY = cell.imageView.center.y
                    serrataTransition.interactor.hasStarted = true

                    selectedCell.onDismissAnimationDidStart()

                    dismiss(animated: true) {
                        if self.isDecideDismiss {
                            self.closeBrowser()
                        }
                    }
            }

        case .changed:
            let translation = sender.translation(in: view)
            panImageViewCenterY = selectedCell.imageView.center.y + translation.y
            selectedCell.imageView.center.y = panImageViewCenterY
            sender.setTranslation(.zero, in: view)

            let verticalMovement = originPanImageViewCenterY - panImageViewCenterY
            /// 0.0 <-> 1.0
            let verticalPercent = fabs(verticalMovement / view.frame.height)
            serrataTransition.interactor.update(verticalPercent)
            rotationBlackImageView.alpha = 1 - verticalPercent

        case .cancelled, .ended, .failed:
            isShouldAutorotate = true
            serrataTransition.interactor.hasStarted = false

            let velocityY = fabs(sender.velocity(in: view).y)
            let isScrollUp = (originPanImageViewCenterY - panImageViewCenterY) > 0

            if velocityY > 800 {
                view.isUserInteractionEnabled = false
                isDecideDismiss = true

                UIView.animate(withDuration: 0.3, animations: {
                    self.rotationBlackImageView.alpha = 0
                    let height = self.view.frame.height
                    self.selectedCell.frame.origin.y = isScrollUp ? -height : height
                }, completion: { _ in
                    self.serrataTransition.interactor.finish()
                })

            } else {
                serrataTransition.interactor.cancel()
                showAppearance()

                UIView.animate(withDuration: 0.3, animations: {
                    self.rotationBlackImageView.alpha = 1
                    self.selectedCell.imageView.center.y = self.originPanImageViewCenterY
                }, completion: { _ in
                    self.isUnderAnimation = false
                    self.selectedCell.onDismissAnimationDidEnd()
                })
            }

        default:
            break
        }
    }

    // MARK: Private Methods -
    private func setPageIndexOffSet(_ pageIndex: Int) {
        let screenWidth = UIScreen.main.bounds.width
        let newOffSetX = screenWidth * CGFloat(pageIndex)
        let totalSpaceX = SlideLeafConst.minimumLineSpacing * CGFloat(pageIndex)
        let newOffSet = CGPoint(x: newOffSetX + totalSpaceX, y: 0)

        collectionView.setContentOffset(newOffSet, animated: false)
    }

    private func closeBrowser() {
        photoDetailView?.beforeGalleryClose()

        if pageIndex >= 0 && pageIndex < photos.count {
            self.delegate?.browserDismissed(photo: photos[pageIndex], pageIndex: pageIndex)
        }
    }

    private func showAppearance() {
        guard isAppearanceVisible == false else { return }

        isStatusBarHidden = false
        isPrefersHomeIndicatorAutoHidden = false

        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }

        let cell = collectionView.cellForItem(at: IndexPath(item: pageIndex, section: 0)) as? SlideLeafCell
        if let bottomViewHeight = photoDetailView?.bottomViewHeight {
            cell?.zoomImageProgressRingBottomConstraint.constant = bottomViewHeight + 7
        }

        UIView.animate(withDuration: 0.150, animations: { [weak self] in
            self?.setNeedsStatusBarAppearanceUpdate()

            cell?.restoreView.alpha = 1
            self?.photoDetailView?.alpha = 1
            self?.photoDetailView?.layoutIfNeeded()
        }) { [weak self] _ in
            self?.isAppearanceVisible = true
        }
    }

    private func hideAppearance() {
        guard isAppearanceVisible == true else { return }

        isStatusBarHidden = true
        isPrefersHomeIndicatorAutoHidden = true

        photoDetailView?.alpha = 0
        photoDetailView?.layoutIfNeeded()

        // TODO: Придумать что-то с анимацией статус бара
        setNeedsStatusBarAppearanceUpdate()
        if #available(iOS 11.0, *) {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }

        if let cell = collectionView.cellForItem(at: IndexPath(item: pageIndex, section: 0)) as? SlideLeafCell {
            cell.restoreView.alpha = 0
            cell.zoomImageProgressRingBottomConstraint.constant = 7
        }

        isAppearanceVisible = false
    }
}

extension SlideLeafViewController: UIScrollViewDelegate
{
    // MARK: Change page index
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var visibleRect = CGRect()
        visibleRect.origin = collectionView.contentOffset
        visibleRect.size = collectionView.bounds.size
        let visiblePoint = CGPoint(x: CGFloat(visibleRect.midX), y: CGFloat(visibleRect.midY))

        if let visibleIndexPath = collectionView.indexPathForItem(at: visiblePoint) {
            pageIndex = visibleIndexPath.item != pageIndex ? visibleIndexPath.item : pageIndex
        }
    }
}

// MARK: Data Manipulation -
extension SlideLeafViewController
{
    func update(_ vkPhotos: [VKPhoto], from state: [VKPhoto]) {
        if state.isEmpty {
            dismiss(animated: true) { [weak self] in self?.closeBrowser() }
            return
        }

        let reload = { [weak self] in
            guard let this = self else { return }

            // Обновляем инфу о фотках в сетке
            let reloadCurrentPhoto = { [weak self] in
                guard
                    let this = self,
                    this.pageIndex >= 0 && this.pageIndex < this.photos.count,
                    // Нам нужно обновить по сути только фотку которую мы сейчас видим
                    vkPhotos.contains(this.photos[this.pageIndex])
                    else { return }

                this.collectionView.reloadItems(at: [IndexPath(item: this.pageIndex, section: 0)])
                this.photoDetailView?.adjustToPhoto(this.photos[this.pageIndex], with: this.pageIndex)
            }

            let currentPhoto = 0..<this.photos.count ~= this.pageIndex ? this.photos[this.pageIndex] : nil
            let changes = diff(old: this.photos, new: state) // TODO: Плохо что диф происходит каждый раз при обновлении

            this.photos = state

            guard !changes.isEmpty else {
                // I.
                // Наиболее частый кейс - изменений в галерее нет,
                // а значит нам нужно просто обновить визуал о текущей видимой фотке
                reloadCurrentPhoto()
                return
            }

            // II. Если есть изменения в сетке - делаем перестановки в коллекции
            if currentPhoto != nil, let currentPhotoIndex = this.photos.index(of: currentPhoto!) {
                // II.1
                // ... текущая фотка все еще в стейте, а значит анимация не нужна, нужно просто
                // остаться на той же фотке что была до изменений
                this.collectionView.reloadData() // Обновляем визуал галереи TODO: Точно нужно делать весь reloadData?
                this.setPageIndexOffSet(currentPhotoIndex) // Без анимации показываем фотку, которую наблюдали TODO: возможно с мерцанием
                this.pageIndex = currentPhotoIndex // Аджастим инфу о фотке (через didSet)
                return
            } else {
                // II.2
                // Текущей фотки нет в будущем стейте - анимируем

                if (this.pageIndex >= this.photos.count) {
                    // Нужно сдвинуть pageIndex если его больше нет в диапазоне
                    this.pageIndex = this.photos.count - 1
                }

                this.collectionView.reload(changes: changes) { _ in
                    // Коллекция изменена из нового стейта, самое время обновить конкретные фото
//                        let indexPathsToReload = vkPhotos.compactMap({ vkPhoto -> IndexPath? in
//                            // TODO: Это должно происходить в методе выше `reload`, но для этого надо указать все поля структуры VKPhoto в функции сравнения
//                            guard let index = this.photos.index(of: vkPhoto) else { return nil }
//                            return IndexPath(item: index, section: 0)
//                        })
//
//                        // Это мы делаем, потому что reload DeepDiff'a не может изменить визуал фоток
//                        // которые отличаются по параметрам не указанным в `==`
//                        this.collectionView.reloadItems(at: indexPathsToReload)

                    reloadCurrentPhoto()
                    return
                }
            }
        }

        isUnderAnimation
            ? adjustPhotoPlease = reload
            : reload()
    }
}

extension SlideLeafViewController: SlideLeafCellDelegate
{
    func slideLeafScrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if scrollView.zoomScale != scrollView.maximumZoomScale {
            hideAppearance()
        }
    }

    func slideLeafScrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale == 1 {
            showAppearance()
        }
    }

    func longPressImageView() {
//        let vkPhoto = photos[pageIndex]
//        delegate?.longPressImageView(slideLeafViewController: self, photo: vkPhoto, pageIndex: pageIndex)
    }
}

extension SlideLeafViewController: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? SlideLeafCell else {
            dismiss(animated: true) { [weak self] in
                self?.closeBrowser()
            }

            return
        }

        willDisplayPhotoAt?(indexPath.row, pageIndex)

        cell.delegate = self
        cell.scrollView.setZoomScale(1, animated: false)
        singleTapGesture.require(toFail: cell.zoomTapGesture)

        if isAppearanceVisible, let bottomViewHeight = photoDetailView?.bottomViewHeight {
            cell.zoomImageProgressRingBottomConstraint.constant = bottomViewHeight + 7
        } else {
            cell.zoomImageProgressRingBottomConstraint.constant = 7
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        delegate?.photoDidDisplayed(atIndex: pageIndex)

        if let cell = collectionView.cellForItem(at: indexPath) as? SlideLeafCell {
            cell.imageView.kf.cancelDownloadTask() // TODO: Check canceling image downloading
        }
    }
}

extension SlideLeafViewController: UICollectionViewDataSourcePrefetching
{
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let imageUrlsToPrefetch = indexPaths.compactMap { indexPath -> URL? in
            guard indexPath.row <= photos.count else { return nil }

            if let imageUrl = photos[indexPath.row].getVKSize(byType: "y")?.getUrl() {
                return URL(string: imageUrl)
            }

            return nil
        }

        if imageUrlsToPrefetch.count > 0 {
            ImagePrefetcher(urls: imageUrlsToPrefetch).start()
        }
    }
}

extension SlideLeafViewController: UICollectionViewDataSource
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SlideLeafCell", for: indexPath) as! SlideLeafCell

        if !photos.isEmpty && indexPath.item <= photos.count {
            cell.vkPhoto = photos[indexPath.item]
            cell.restoreView.alpha = isAppearanceVisible ? 1 : 0
        }

        return cell
    }
}

extension SlideLeafViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return UIScreen.main.bounds.size
    }
}

extension SlideLeafViewController: GalleryDelegate
{
    func close() {
        dismiss(animated: true) { [weak self] in
            self?.closeBrowser()
        }
    }

    func presentViewController(_ viewController: UIViewController) {
        present(viewController, animated: true)
    }
}
