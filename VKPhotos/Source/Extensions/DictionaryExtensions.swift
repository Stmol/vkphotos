//
// Created by Yury Smidovich on 16/03/2018.
// Copyright (c) 2018 Yury Smidovich. All rights reserved.
//

extension Dictionary {

    mutating func append(_ dic: Dictionary) {
        for (key, value) in dic {
            self[key] = value
        }
    }

}
