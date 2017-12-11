//
//  Dependency.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


public struct Dependency: Hashable {
    
    public enum Relationship {
        case precessor
        case successor
        case parent
    }
    
    public let relationship: Relationship
    public let original: AnyTask
    public let hashValue: Int
    
    public init<T: Task>(task: T, relationship: Relationship) {
        self.original = task
        self.relationship = relationship
        self.hashValue = task.hashValue
    }

    
    init(anyTask task: AnyTask, relationship: Relationship) {
        self.original = task
        self.relationship = relationship
        self.hashValue = task.hashValue
    }

    
    public static func ==(lhs: Dependency, rhs: Dependency) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
