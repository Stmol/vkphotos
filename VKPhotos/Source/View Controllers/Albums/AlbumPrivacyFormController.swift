//
// Created by Yury Smidovich on 03/04/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import UIKit

protocol AlbumPrivacyFormDelegate: class {
    func privacyDidSelect(_ value: VKPrivacy)
}

class AlbumPrivacyFormController: UITableViewController {
    @IBOutlet weak var allUsersCell: AlbumPrivacyFormCell! {
        didSet {
            let privacy = VKPrivacy([.string(PrivacyAccess.All.rawValue)])
            allUsersCell.vkPrivacy = privacy
            allUsersCell.textLabel?.text = privacy.transcript
        }
    }
    @IBOutlet weak var onlyMeCell: AlbumPrivacyFormCell! {
        didSet {
            let privacy = VKPrivacy([.string(PrivacyAccess.OnlyMe.rawValue)])
            onlyMeCell.vkPrivacy = privacy
            onlyMeCell.textLabel?.text = privacy.transcript
        }
    }
    @IBOutlet weak var friendsCell: AlbumPrivacyFormCell! {
        didSet {
            let privacy = VKPrivacy([.string(PrivacyAccess.Friends.rawValue)])
            friendsCell.vkPrivacy = privacy
            friendsCell.textLabel?.text = privacy.transcript
        }
    }
    @IBOutlet weak var friendsOfCell: AlbumPrivacyFormCell! {
        didSet {
            let privacy = VKPrivacy([.string(PrivacyAccess.FriendsOfFriends.rawValue)])
            friendsOfCell.vkPrivacy = privacy
            friendsOfCell.textLabel?.text = privacy.transcript
        }
    }
    @IBOutlet weak var someFriendsCell: AlbumPrivacyFormCell! {
        didSet {
            someFriendsCell.textLabel?.text = VKPrivacy([.int(1)]).transcript
        }
    }
    @IBOutlet weak var someListsCell: AlbumPrivacyFormCell! {
        didSet {
            someListsCell.textLabel?.text = VKPrivacy([.string("_list_")]).transcript
        }
    }

    var selectedVKPrivacy: VKPrivacy!
    weak var delegate: AlbumPrivacyFormDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        clearSelection()
        if let privacyAccess = selectedVKPrivacy.privacyAccess {
            switch privacyAccess {
            case .OnlyMe, .Nobody: onlyMeCell.accessoryType = .checkmark
            case .All: allUsersCell.accessoryType = .checkmark
            case .Friends: friendsCell.accessoryType = .checkmark
            case .FriendsOfFriends, .FriendsOfFriendsOnly: friendsOfCell.accessoryType = .checkmark
            }
        } else {
            if selectedVKPrivacy.isAllowedForFriendsListsOnly {
                someListsCell.accessoryType = .checkmark
            } else if selectedVKPrivacy.isAllowedForSomeFriendsOnly {
                someFriendsCell.accessoryType = .checkmark
            }
        }
    }
}

extension AlbumPrivacyFormController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        clearSelection()

        if let cell = tableView.cellForRow(at: indexPath) as? AlbumPrivacyFormCell, let privacy = cell.vkPrivacy {
            cell.accessoryType = (cell.accessoryType == .checkmark) ? .none : .checkmark
            delegate.privacyDidSelect(privacy)
        }
    }

    fileprivate func clearSelection() {
        allUsersCell.accessoryType = .none
        onlyMeCell.accessoryType = .none
        friendsCell.accessoryType = .none
        friendsOfCell.accessoryType = .none
        someListsCell.accessoryType = .none
        someFriendsCell.accessoryType = .none
    }
}
