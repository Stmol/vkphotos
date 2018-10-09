//
//  LicensesTableController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 21/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit
import Crashlytics

struct License: Decodable {
    let name: String
    let text: String
}

class LicensesTableController: UITableViewController {
    let showLicenseSegueID = "showLicenseSegue"

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    fileprivate var licenses = [License]()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.tintColor = .white
        clearsSelectionOnViewWillAppear = true
        tableView.tableFooterView = UIView()

        let items = Bundle.main.urls(forResourcesWithExtension: "license", subdirectory: nil)!

        do {
            for item in items {
                licenses.append(License(
                    name: item.deletingPathExtension().lastPathComponent,
                    text: try String(contentsOf: item, encoding: .utf8)
                ))
            }

            licenses.sort(by: { $0.name < $1.name })
            tableView.reloadData()
        } catch {
            Crashlytics.sharedInstance().recordError(error)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == showLicenseSegueID, let license = sender as? License else { return }

        if let controller = segue.destination as? LicenseController {
            controller.license = license
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return licenses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "licenseCell", for: indexPath)
        cell.textLabel?.text = licenses[indexPath.item].name

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) != nil {
            performSegue(withIdentifier: showLicenseSegueID, sender: licenses[indexPath.item])
        }
    }
}
