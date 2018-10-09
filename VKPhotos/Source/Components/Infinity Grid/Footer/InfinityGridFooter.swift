//
//  InfinityGridFooterView.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 25/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class InfinityGridFooter: UIView {
    @IBOutlet weak var statusLabel: UILabel! {
        didSet {
            statusLabel.isHidden = false
            statusLabel.alpha = 0
        }
    }

    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView! {
        didSet {
            loadingIndicator.isHidden = false
            loadingIndicator.alpha = 1
        }
    }

    func hide(withAnim: Bool = true) {
        if withAnim {
            UIView.animate(withDuration: 0.1, animations: { [weak self] in
                self?.statusLabel.alpha = 0
                self?.loadingIndicator.alpha = 0
            })
        } else {
            statusLabel.alpha = 0
            loadingIndicator.alpha = 0
        }
    }

    func startLoading() {
        statusLabel.alpha = 0
        loadingIndicator.alpha = 1
    }

    func stopLoading(_ withMessage: String?) {
        loadingIndicator.alpha = 0

        guard let text = withMessage, !text.isEmpty else { return }
        statusLabel.text = text
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            self?.statusLabel.alpha = 1
        })
    }
}
