//
//  ResolvedDependency.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


private class WorkForce {
    static let shared = WorkForce()
    var worker = [Int: AnyWorker]()
    private init() { }
}


class ManagedTask {
    
    let original: AnyTask
    
    var result: TaskResult
    var dependencies: Set<Dependency>
    var state: State
    var completionHandler: [CompletionHandler]

    var worker: AnyWorker {
        get {
            if let worker = WorkForce.shared.worker[hashValue] {
                return worker
            } else {
                let newWorker = original.createWorker()
                WorkForce.shared.worker[hashValue] = newWorker
                return newWorker
            }
        }
    }
    

    init(original: AnyTask) {
        self.original = original
        self.result = .none
        self.dependencies = Set()
        self.state = .unresolved
        self.completionHandler = []
    }
    
    
    deinit {
        removeWorker()
    }
    
    
    func removeWorker() {
        WorkForce.shared.worker.removeValue(forKey: hashValue)
    }
}



extension ManagedTask: Hashable {
    
    var hashValue: Int {
        return original.hashValue
    }
    
    
    static func ==(lhs: ManagedTask, rhs: ManagedTask) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}



extension ManagedTask {
    
    struct CompletionHandler {
        let handler: (Any?) -> ()
    }
}



extension ManagedTask {
    
    enum State {
        case unresolved
        case executing
        case resultObtained
        case completed
    }
}


extension ManagedTask {
    
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
}
