//
//  TabBarController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 07/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Kingfisher
import VKSdkFramework

class TabBarController: UITabBarController {
    private var isNeedToLogin = false

    override func viewDidLoad() {
        super.viewDidLoad()
        startListen(.vkUserLogout, self, #selector(onVKUserLogout))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isNeedToLogin {
            showVKLoginController()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //selectedIndex = 2
    }

    @objc func onVKUserLogout(_ notification: NSNotification) {
        VKSdk.forceLogout()

        let currentController = getVisibleViewController(self)
        if currentController != self {
            // TODO: Надо придумать как закрыть модалки и вернуться в рут контроллер
            //currentController?.dismiss(animated: false) { [weak self] in self?.showVKLoginController() }
            isNeedToLogin = true
        } else {
            showVKLoginController()
        }
    }

    fileprivate func showVKLoginController() {
        let loginController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "VKLoginViewController") as! VKLoginViewController

        present(loginController, animated: true)
    }
}
