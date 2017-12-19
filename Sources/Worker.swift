//
//  Worker.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation

public enum Report {
    case done
    case retry
    case internalError
}


protocol AnyWorker: class {
    var dependencies: Set<Dependency> { get }
    var dependencyState: DependencyState { get set }
    var anyTask: AnyTask { get }
    var result: TaskResult { get set }
    var completionHandler: [CompletionHandler] { get set }

    func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void)
    func callCompletionHandlers()
    func cleanUp(report: @escaping (Report) -> Void)
}


open class Worker<T: Task>: AnyWorker {
    
    // External
    public private(set) var task: T
    
    // External Overridable
    public var parallelChildTasks: Int { return 1 }
    public class var parallelWorkers: Int { return 1 }

    // Internal
    var completionHandler: [CompletionHandler]
    var anyTask: AnyTask { return task }
    private(set) var dependencies: Set<Dependency>
    var dependencyState: DependencyState
    var result: TaskResult

    
    public required init(task: T) {
        self.task = task
        self.result = .none
        self.dependencies = []
        self.dependencyState = .unresolved
        self.completionHandler = []
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
    
    
    open func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        report(.done, nil)
    }
    
    
    open func cleanUp(report: @escaping (Report) -> Void) {
        report(.done)
    }
    
    
    open func cancel(report: @escaping (Report) -> Void) {
        report(.done)
    }
    
    
    func callCompletionHandlers() {
        if let result = self.result.obtainedResult {
            completionHandler.forEach { $0.handler(result) }
        }
        completionHandler.removeAll()
    }
}


struct CompletionHandler {
    let handler: (Any) -> ()
}


enum DependencyState {
    case unresolved
    case added
    case interlinked
}


enum TaskResult {
    case obtained(Any?)
    case none
    
    var isObtained: Bool {
        if case .obtained = self {
            return true
        }
        return false
    }
    
    var isNone: Bool {
        if case .none = self {
            return true
        }
        return false
    }
    
    var obtainedResult: Any? {
        if case .obtained(let result) = self {
            return result
        }
        return nil
    }
}

