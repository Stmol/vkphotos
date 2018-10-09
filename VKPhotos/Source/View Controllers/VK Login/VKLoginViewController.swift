//
//  VKLoginViewController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 09/02/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import VKSdkFramework
import Firebase

class VKLoginViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var shouldAutorotate: Bool { return false }

    @IBOutlet weak var loginActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loginStatusLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var vkRulesLinkLabel: UILabel! {
        didSet {
            vkRulesLinkLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onVKRulesLinkTap)))
        }
    }
    @IBOutlet weak var appRulesLabel: UILabel! {
        didSet {
            appRulesLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onAppRulesTap)))
        }
    }
    @IBOutlet weak var vkPrivacyPolicyLabel: UILabel! {
        didSet {
            vkPrivacyPolicyLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onVKPrivacyPolicyLinkTap)))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        VKSdk.instance().uiDelegate = self
        VKSdk.instance().register(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loginInProgress()
        if VKSdk.isLoggedIn() {
            loginButton.isHidden = true
            loginActivityIndicator.isHidden = false

            showAppScreen()
        } else {
            loginEnd()
        }
    }

    @IBAction func onLoginPress(_ sender: UIButton) {
        if VKSdk.isLoggedIn() { showAppScreen() }

        loginInProgress()
        VKSdk.authorize(VK_SCOPES, with: [.disableSafariController])
    }

    @objc func onVKRulesLinkTap(_ sender: UILabel) {
        if let url = URL(string: getVKTermsURL()) {
            Analytics.logEvent(AnalyticsEvent.TapVKRules, parameters: ["screen": "login"])
            UIApplication.shared.open(url, options: [:])
        }
    }

    @objc func onVKPrivacyPolicyLinkTap(_ sender: UILabel) {
        if let url = URL(string: getVKPrivacyURL()) {
            Analytics.logEvent(AnalyticsEvent.TapVKPrivacyPolicy, parameters: ["screen": "login"])
            UIApplication.shared.open(url, options: [:])
        }
    }

    @objc func onAppRulesTap(_ sender: UILabel) {
        Analytics.logEvent(AnalyticsEvent.TapLoginAppRules, parameters: nil)
        performSegue(withIdentifier: "showRulesSegue", sender: nil)
    }

    private func showAppScreen() {
        self.performSegue(withIdentifier: "showAppSegue", sender: self)
    }

    private func loginInProgress() {
        loginButton.isHidden = true
        loginStatusLabel.isHidden = true
        loginActivityIndicator.isHidden = false
    }

    private func loginEnd(withError error: String? = nil) {
        loginButton.isHidden = false
        loginActivityIndicator.isHidden = true

        if let error = error {
            loginStatusLabel.isHidden = false
            loginStatusLabel.text = error
        }
    }
}

extension VKLoginViewController: VKSdkUIDelegate {
    func vkSdkShouldPresent(_ controller: UIViewController!) {
        print("VK DELEGATE: vkSdkShouldPresent")
        present(controller, animated: true)
    }

    func vkSdkNeedCaptchaEnter(_ captchaError: VKError!) {
        print("VK DELEGATE: Need Captcha")
        Analytics.logEvent(AnalyticsEvent.VKNeedCaptcha, parameters: nil)

        if let vkCaptchaViewController = VKCaptchaViewController.captchaControllerWithError(captchaError) {
            present(vkCaptchaViewController, animated: true)
        }
    }
}

extension VKLoginViewController: VKSdkDelegate {
    func vkSdkAccessAuthorizationFinished(with result: VKAuthorizationResult!) {
        print("VK DELEGATE: Authorization Finished")
        loginEnd()

//        switch result.state {
//            case .pending, .external, .safariInApp, .webview, .authorized:
//                loginInProgress()
//                break
//            case .unknown, .initialized, .error:
//                loginEnd(withError: "Ошибка авторизации :(")
//                break
//        }
    }

    func vkSdkUserAuthorizationFailed() {
        Analytics.logEvent(AnalyticsEvent.VKAuthFailed, parameters: nil)
        loginEnd(withError: "Ошибка авторизации :(")
    }

    func vkSdkAuthorizationStateUpdated(with result: VKAuthorizationResult!) {
        print("VK DELEGATE: AuthorizationStateUpdated")

        if
            result.state == .authorized,
            isViewLoaded == true,
            view.window != nil
        {
            loginEnd()
            showAppScreen()
        }
    }

    func vkSdkTokenHasExpired(_ expiredToken: VKAccessToken!) {
        print("VK DELEGATE: vkSdkTokenHasExpired")
        loginEnd()
        Analytics.logEvent(AnalyticsEvent.VKTokenExpired, parameters: nil)
    }

    func vkSdkAccessTokenUpdated(_ newToken: VKAccessToken!, oldToken: VKAccessToken!) {
        print("VK DELEGATE: AccessTokenUpdated")
        Analytics.logEvent(AnalyticsEvent.VKTokenUpdated, parameters: nil)
    }
}
