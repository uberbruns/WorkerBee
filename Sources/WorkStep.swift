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


class WorkStep {
    
    let original: AnyTask
    
    var result: TaskResult
    var dependencies: Set<TypeErasedTask>
    var state: State
    var phase: Phase

    var worker: AnyWorker {
        if let worker = WorkForce.shared.worker[hashValue] {
            return worker
        } else {
            let newWorker = original.createWorker()
            WorkForce.shared.worker[hashValue] = newWorker
            return newWorker
        }
    }
    

    init(original: AnyTask, phase: Phase) {
        self.original = original
        self.phase = phase
        self.result = .none
        self.dependencies = Set()
        self.state = .unresolved
    }
    
    
    deinit {
        removeWorker()
    }
    
    
    func removeWorker() {
        WorkForce.shared.worker.removeValue(forKey: hashValue)
    }
}



extension WorkStep: Hashable {
    
    var hashValue: Int {
        var hashValue = original.hashValue
        extendHash(&hashValue, with: phase.rawValue)
        return hashValue
    }
    
    
    static func ==(lhs: WorkStep, rhs: WorkStep) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}



extension WorkStep {
    
    enum State {
        case unresolved
        case executing
        case completed
    }
}


extension WorkStep {
    
    enum Phase: Int {
        case main
        case callCompletionHandler
        case cleanUp
    }
}


extension WorkStep {
    
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
