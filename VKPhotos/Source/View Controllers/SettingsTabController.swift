//
//  SettingsTabController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 14/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Kingfisher
import VKSdkFramework
import Firebase
import StoreKit

private struct SettingsTabControllerConst {
    static let avatarImageViewSize = CGFloat(80)
    static let imageCacheSizeLimit = 150 * 1024 * 1024 // 150 Mb

    static let showLicensesListSegue = "showLicensesListSegue"

    static let clearImageCacheCellID = "clearImageCacheCell"
    static let logoutButtonCellID = "logoutButtonCell"
    static let vkGroupLinkCellID = "vkGroupLinkCell"
    static let licensesButtonCellID = "licensesButtonCell"
    static let vkPrivacyButtonCellID = "vkPrivacyButtonCell"
    static let appVersionCellID = "appVersionCell"
    static let rateAppCellID = "rateAppCell"
    static let shareAppCellID = "shareAppCell"

    static let limitImageCacheKey = "vk_photos.image_cache.is_limit"

    static let vkGroupURL = "https://vk.com/vkphotos_app"
    static let appStoreReviewURL = "https://itunes.apple.com/app/id\(APP_STORE_APP_ID)?action=write-review"
    static let appStoreURL = "https://itunes.apple.com/app/id\(APP_STORE_APP_ID)"
}

class SettingsTabController: UITableViewController {
    fileprivate typealias Const = SettingsTabControllerConst

    @IBOutlet weak var albumsCountLabel: UILabel!
    @IBOutlet weak var photosCountLabel: UILabel!
    @IBOutlet weak var imagesCacheSizeLabel: UILabel!
    @IBOutlet weak var imageCacheSizeLimitSwitch: UISwitch!
    @IBOutlet weak var appVersionLabel: UILabel! {
        didSet {
            guard
                let dic = Bundle.main.infoDictionary,
                let version = dic["CFBundleShortVersionString"] as? String
                //let build = dic["CFBundleVersion"] as? String
                else { return }

            appVersionLabel.text = "\(version)"
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    fileprivate var headerView: SettingsTabHeaderView = { return .fromNib() }()
    fileprivate var vkUser: VKUser!
    fileprivate let api = VKApiClient()
    fileprivate var isCacheClearInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let token = VKSdk.accessToken(), let user = token.localUser else {
            dispatch(.vkUserLogout, nil); return
        }

        vkUser = user
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateCacheSizeLabel()

        api.getMetaInfo().then { [weak self] info in
            self?.albumsCountLabel.text = info.albumsCount > 0 ? String(info.albumsCount + 4) : "0"
            self?.photosCountLabel.text = String(info.photosCount)
        }
    }

    fileprivate func setupUI() {
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        self.clearsSelectionOnViewWillAppear = false

        // Аватарка
        if let avatarUrl = URL(string: vkUser.photo_200) {
            headerView.userAvatarImageView.kf.setImage(
                with: avatarUrl,
                options: [.transition(.fade(0.2)), .targetCache(commonImageCache)]
            )
        }

        var userName = ""
        if let firstName = vkUser.first_name {
            userName = firstName
        }

        if let lastName = vkUser.last_name {
            userName = userName.isEmpty ? lastName : "\(userName) \(lastName)"
        }

        headerView.userNameLabel.text = userName

        headerView.widthAnchor.constraint(equalToConstant: tableView.frame.width).isActive = true
        tableView.tableHeaderView = headerView

        if let isLimit = UserDefaults.standard[Const.limitImageCacheKey] as? Bool {
            imageCacheSizeLimitSwitch.isOn = isLimit
        }
    }

    fileprivate func updateCacheSizeLabel() {
        ImageCache.default.calculateDiskCacheSize { [weak self] size in
            self?.imagesCacheSizeLabel.text = self?.format(bytes: Double(size)) ?? "—"
        }
    }

    fileprivate func clearImageCache() {
        guard isCacheClearInProgress == false else { return }

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(title: "Cancel".localized(), style: .cancel, isEnabled: true, handler: nil)
        actionSheet.addAction(title: "Clear Cache".localized(), style: .destructive, isEnabled: true, handler: { [weak self] _ in
            Analytics.logEvent(AnalyticsEvent.ImageCacheClear, parameters: nil)

            self?.isCacheClearInProgress = true
            ImageCache.default.clearDiskCache { [weak self] in
                self?.updateCacheSizeLabel()
                self?.isCacheClearInProgress = false
            }
        })

        present(actionSheet, animated: true)
    }

    fileprivate func logout() {
        let alertController = UIAlertController(
            title: "Logging Out".localized(),
            message: "Log out info".localized(),
            defaultActionButtonTitle: "Cancel".localized(),
            tintColor: nil)

        alertController.addAction(title: "OK", style: .default, isEnabled: true) { [weak self] _ in
            HUD.show(.loading)

            if self?.vkUser.id != nil {
                Analytics.logEvent(AnalyticsEvent.Logout, parameters: nil)
            }

            /// MARK: Cleanup
            // 1) Чистим кеш файлов TODO: надо ли почистить память?
            // TODO: Надо чистить при любом разлогине, например если от АПИ пришел код 4 или 5
            ImageCache.default.clearDiskCache { [weak self] in
                VKSdk.forceLogout() // 2) Делаем логаут из ВК
                let domain = Bundle.main.bundleIdentifier! // 3) Чистим настройки на устройстве
                UserDefaults.standard.removePersistentDomain(forName: domain)
                UserDefaults.standard.synchronize()

                HUD.hide(afterDelay: 0) { [weak self] _ in
                    let loginController = UIStoryboard(name: "Main", bundle: nil)
                        .instantiateViewController(withIdentifier: "VKLoginViewController") as! VKLoginViewController

                    self?.present(loginController, animated: true)
                }
            }
        }

        present(alertController, animated: true)
    }

    fileprivate func shareApp() {
        let shareController = UIActivityViewController(activityItems: [Const.appStoreURL], applicationActivities: nil)
        shareController.completionWithItemsHandler = { [weak self] activityType, result, _, error in
            guard let activityType = activityType, result == true else {
                return
            }

            if error != nil {
                Crashlytics.sharedInstance().recordError(error!)
                HUD.flash(.error, onView: self?.view, delay: 1.3)
                return
            }

            Analytics.logEvent(AnalyticsEvent.ShareAppLink, parameters: [
                "activity_type": activityType.rawValue
            ])
        }

        present(shareController, animated: true)
    }

    fileprivate func openURL(_ url: String) {
        if let url = URL(string: url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    fileprivate func format(bytes: Double) -> String {
        guard bytes > 0 else {
            return "0 b"
        }

        let suffixes = ["b", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        let k: Double = 1000
        let i = floor(log(bytes) / log(k))

        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = i < 3 ? 0 : 1
        numberFormatter.numberStyle = .decimal

        let numberString = numberFormatter.string(from: NSNumber(value: bytes / pow(k, i))) ?? "Unknown"
        let suffix = suffixes[Int(i)]

        return "\(numberString) \(suffix)"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell.reuseIdentifier {
            case Const.clearImageCacheCellID:
                clearImageCache()
            case Const.vkGroupLinkCellID:
                Analytics.logEvent(AnalyticsEvent.TapVKGroup, parameters: nil)
                openURL(Const.vkGroupURL)
            case Const.vkPrivacyButtonCellID:
                Analytics.logEvent(AnalyticsEvent.TapVKPrivacyPolicy, parameters: ["screen": "settings"])
                openURL(getVKPrivacyURL())
            case Const.licensesButtonCellID:
                Analytics.logEvent(AnalyticsEvent.TapLicenses, parameters: nil)
                performSegue(withIdentifier: Const.showLicensesListSegue, sender: self)
            case Const.logoutButtonCellID: logout()
            case Const.rateAppCellID:
                Analytics.logEvent(AnalyticsEvent.TapAppStoreReview, parameters: nil)
                openURL(Const.appStoreReviewURL)
            case Const.shareAppCellID:
                shareApp()
            default: break
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func imageCacheSizeLimitSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard[Const.limitImageCacheKey] = sender.isOn
        /* The disk cache will not be purged until you switch your app to background
           or you call the cleanExpiredDiskCacheWithCompletionHander method manually.
           It will swipe the your disk cache to a size under the limitation. */
        ImageCache.default.maxDiskCacheSize = UInt(sender.isOn ? Const.imageCacheSizeLimit : 0)
    }
}
