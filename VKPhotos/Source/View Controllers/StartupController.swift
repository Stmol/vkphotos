//
//  StartupController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 09/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import VKSdkFramework
import Kingfisher
import Crashlytics
import Firebase
import Reachability

// В этом кешере хранятся изображения, которые не надо сбрасывать вместе с фото из галереи:
// например аватарки пользователей
let commonImageCache = ImageCache(name: "common_images")

class StartupController: UIViewController {
    deinit {
        reachability.stopNotifier()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    private let reachability = Reachability()!

    override func viewDidLoad() {
        super.viewDidLoad()

        commonAppSetup()

        reachability.whenReachable = { [weak self] reachability in
            if reachability.connection == .wifi {
                Analytics.setUserProperty("wifi", forName: "connection_type")
            } else {
                Analytics.setUserProperty("cell", forName: "connection_type")
            }

            // TODO!! Навсегда повиснит прелоадер если не будет интернет соединения
            self?.attemptToLogin()
        }

        do {
            try reachability.startNotifier()
        } catch {
            Crashlytics.sharedInstance().recordError(error)
        }
    }

    private func commonAppSetup() {
        VKSdk.initialize(withAppId: VK_APP_ID, apiVersion: VK_API_V)

        GSMessage.font = UIFont.boldSystemFont(ofSize: 16)
        GSMessage.warningBackgroundColor = UIColor(red: 0.901961, green: 0.741176, blue: 0.00392157, alpha: 1)
        GSMessage.infoBackgroundColor = UIColor(red: 0.172549, green: 0.733333, blue: 1, alpha: 1)
        GSMessage.errorBackgroundColor = GSMessage.errorBackgroundColor.withAlphaComponent(1)

//        DispatchQueue.global(qos: .userInitiated).async {
//            ImageCache.default.maxDiskCacheSize = 300 * 1024 * 1024 // 300 Mb
//            ImageCache.default.maxCachePeriodInSecond = 60 * 60 * 24 * 1 // 1 Day
//        }
    }

    private func showLoginScreen() {
        let loginController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "VKLoginViewController") as! VKLoginViewController

        present(loginController, animated: true)
    }

    private func showAppScreen() {
        performSegue(withIdentifier: "showAppSegue", sender: self)
    }

    private func attemptToLogin() {
        VKSdk.wakeUpSession(VK_SCOPES, complete: { state, error in
            if error != nil {
                Crashlytics.sharedInstance().recordError(error!)
            }

            if state == .authorized, VKSdk.accessToken().userId != nil {
                self.showAppScreen()
                return
            }

            self.showLoginScreen()
        })
    }
}
