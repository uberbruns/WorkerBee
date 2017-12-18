//
//  Task.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


public protocol AnyTask {
    var name: String { get }
    var hashValue: Int { get }
    func createWorker() -> AnyWorker
}



public protocol Task: AnyTask {
    associatedtype Result
}


struct TypeErasedTask: Hashable {
    
    public let original: AnyTask
    public let hashValue: Int
    
    
    public init<T: Task>(task: T) {
        self.original = task
        self.hashValue = task.hashValue
    }
    
    
    init(anyTask task: AnyTask) {
        self.original = task
        self.hashValue = task.hashValue
    }
    
    
    public static func ==(lhs: TypeErasedTask, rhs: TypeErasedTask) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
