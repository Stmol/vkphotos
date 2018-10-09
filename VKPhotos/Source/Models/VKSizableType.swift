//
//  VKSizableType.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 28/03/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

// w = 2048
// z = 1024
// y = 807
// x = 604
// m = 130
// s = 75
let vkImageSizeTypes = ["w", "z", "y", "x", "m", "s"]

// r = 510
// q = 320
// p = 200
// o = 130
let vkImageProportionalSizeTypes = ["r", "q", "p", "o"]

struct VKSize: Codable {
    let height: Int
    let width: Int
    let url: String?
    let src: String?
    let type: String

    func getUrl() -> String? {
        return url != nil ? url : (src ?? nil)
    }
}

protocol VKSizable {
    func getVKSize(byType type: String) -> VKSize?
    func getVKSize(byProportionalType type: String) -> VKSize?
    func getSizes() -> [VKSize]?
}

extension VKSizable {
    func getVKSize(byType type: String = "w") -> VKSize? {
        let sizeTypes = vkImageSizeTypes.suffix(from: vkImageSizeTypes.index(of: type)!)

        for sizeType in sizeTypes {
            if let vkSize = getSizes()?.first(where: {$0.type == sizeType}) {
                return vkSize
            }
        }

        return nil
    }

    func getVKSize(byProportionalType type: String = "r") -> VKSize? {
        let sizeTypes = vkImageProportionalSizeTypes.suffix(from: vkImageProportionalSizeTypes.index(of: type)!)

        for sizeType in sizeTypes {
            if let vkSize = getSizes()?.first(where: {$0.type == sizeType}) {
                return vkSize
            }
        }

        return nil
    }
}
