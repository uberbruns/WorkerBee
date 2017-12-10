//
//  Worker.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation

public enum Report {
    case done(Any)
    case retry
    case internalError
}


public protocol AnyWorker: class {
    var dependencies: Set<Dependency> { get }
    var anyTask: AnyTask { get }
    func main(results: [Dependency: Any], report: @escaping (Report) -> Void)
    func finalize(report: @escaping (Report) -> Void)
}


public class Worker<T: Task>: AnyWorker {
    
    public class var parallelWorkers: Int { return 1 }
    
    public private(set) var task: T
    public var anyTask: AnyTask{ return task }
    public private(set) var dependencies: Set<Dependency>
    
    public var numberOfChildTasks: Int { return 1 }
    
    
    public required init(task: T) {
        self.task = task
        self.dependencies = []
    }
    
    
    public func add<T: Task>(dependency task: T, as relationship: Dependency.Relationship) {
        let dependency = Dependency(task: task, relationship: relationship)
        add(dependency: dependency)
    }
    
    
    public func add(dependency: Dependency) {
        dependencies.insert(dependency)
    }
    
    
    public func remove<T: Task>(dependency task: T, as relationship: Dependency.Relationship) {
        let dependency = Dependency(task: task, relationship: relationship)
        remove(dependency: dependency)
    }
    
    
    public func remove(dependency: Dependency) {
        dependencies.remove(dependency)
    }
    
    
    open func main(results: [Dependency: Any], report: @escaping (Report) -> Void) {
        report(.done(Void()))
    }
    
    
    open func finalize(report: @escaping (Report) -> Void) {
        report(.done(Void()))
    }
    
    
    open func cancel(report: @escaping (Report) -> Void) {
        report(.done(Void()))
    }
}
