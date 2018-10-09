//
//  LicenseController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class LicenseController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    @IBOutlet weak var licenseTextLabel: UILabel!

    var license: License!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.tintColor = .white
        navigationItem.title = license.name
        licenseTextLabel.text = license.text
    }
}
