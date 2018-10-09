//
//  Array.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 27/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

extension Array where Element: VKEntityHashable {

    func unique(by: [Element]) -> Array {
        var set = Set<Element>(by)
        return filter { set.insert($0).inserted }
    }

}
