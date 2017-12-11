//
//  Hashing.swift
//  Worker
//
//  Created by Karsten Bruns on 08.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


public func extendHash<T: Hashable>(_ seed: inout Int, with otherHashable: T) {
    // Swift port of http://www.boost.org/doc/libs/1_34_1/boost/functional/hash/hash.hpp
    #if arch(x86_64) || arch(arm64)
        let magic = Int(bitPattern: 0x9e3779b97f4a7c15 as UInt)
    #elseif arch(i386) || arch(arm)
        let magic = Int(bitPattern: 0x9e3779b9 as UInt)
    #endif
    
    let otherHash = otherHashable.hashValue
    seed ^= otherHash &+ magic &+ (seed << 6) &+ (seed >> 2)
}


public func buildHash<T: Hashable>(_ items: T...) -> Int {
    guard !items.isEmpty else { return 0 }
    var items = items
    var result = items.removeFirst().hashValue
    for item in items {
        extendHash(&result, with: item)
    }
    return result
}