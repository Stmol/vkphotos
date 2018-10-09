//
// Created by Yury Smidovich on 12/07/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

import Foundation

struct Messages {

    struct Errors {
        static let failToRefreshData = "Failed to update data".localized()
        static let failToFetchNewData = "Error requesting data".localized()
        static let needToUpdateData = "Must to reload data".localized()
        static let needToRefreshList = "Pull down".localized()
        static let dataInconsistency = "Data on the server has changed".localized()
        static let needToReloadData = "Must to update data".localized()
        static let noInternetConnection = "No Internet connection".localized()
    }

}
