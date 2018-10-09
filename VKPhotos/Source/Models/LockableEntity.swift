//
//  Lockable.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 25/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import Foundation

class LockableEntity<E: Hashable> {
    private var entities = Set<E>()
    private let queue = DispatchQueue(label: "lockable_entity", attributes: .concurrent)

    func lock(_ entity: E) {
        queue.async(flags: .barrier) {
            self.entities.insert(entity)
        }
    }

    func unlock(_ entity: E) {
        queue.async(flags: .barrier) {
            self.entities.remove(entity)
        }
    }

    func isLocked(_ entity: E) -> Bool {
        var isLocked = false
        queue.sync {
            isLocked = self.entities.contains(entity)
        }
        return isLocked
    }

    func free() {
        queue.sync(flags: .barrier) {
            self.entities.removeAll()
        }
    }
}
