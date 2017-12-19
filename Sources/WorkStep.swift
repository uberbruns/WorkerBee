//
//  ResolvedDependency.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


class WorkStep {
    
    let original: AnyTask
    
    var dependencies: Set<WorkStep>
    var state: State
    var phase: Phase

    init(original: AnyTask, phase: Phase) {
        self.original = original
        self.phase = phase
        self.dependencies = Set()
        self.state = .unresolved
    }
    
    
    func waits(for workStep: WorkStep) {
        dependencies.insert(workStep)
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
        case resolved
    }
}


extension WorkStep {
    
    enum Phase: Int {
        case main = 0
        case cleanUp = 1
        case callCompletionHandler = 2
    }
}