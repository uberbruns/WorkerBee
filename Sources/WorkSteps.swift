//
//  WorkSteps.swift
//  Worker-iOS
//
//  Created by Karsten Bruns on 19.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation

class WorkSteps {
    var steps: [Int: WorkStep] {
        didSet {
            printDebugInfo()
        }
    }
    
    
    var values: Dictionary<Int, WorkStep>.Values {
        return steps.values
    }
    
    
    var isEmpty: Bool {
        return steps.isEmpty
    }
    
    
    init() {
        self.steps = [Int: WorkStep]()
    }
    
    
    subscript(task task: AnyTask, phase phase: WorkStep.Phase) -> WorkStep? {
        var hash = task.hashValue
        extendHash(&hash, with: phase.rawValue)
        return steps[hash]
    }
    
    
    @discardableResult func insert(task: AnyTask, phase: WorkStep.Phase) -> WorkStep {
        let workStep = WorkStep(original: task, phase: phase)
        let hash = workStep.hashValue
        steps[hash] = workStep
        return workStep
    }
    
    
    func remove(_ workStep: WorkStep) {
        steps.removeValue(forKey: workStep.hashValue)
    }
    
    
    func printDebugInfo() {
        let comp = steps.values.sorted { (a, b) -> Bool in
            if a.original.name != b.original.name {
                return a.original.name < b.original.name
            } else {
                return a.phase.rawValue < b.phase.rawValue
            }
        }
        
        let lines = comp.map({ (step: WorkStep) -> String in
            let dependencies = step.dependencies.map({ "\($0.original.name) (\($0.phase))" })
            return "\(step.original.name) (\(step.phase)); \(step.state); [\(dependencies.joined(separator: ", "))]"
        })
        
        if lines.isEmpty {
            WorkCoordinator.shared.debugLog("No Work Steps")
        } else {
            WorkCoordinator.shared.debugLog(lines.joined(separator: "\n"))
        }
        
        WorkCoordinator.shared.debugLog("")
    }
}
