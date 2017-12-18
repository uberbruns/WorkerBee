//
//  TaskManager.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


final public class TaskManager {

    // MARK: - Manager -
    // MARK: Properties

    public static let shared = TaskManager()
    private var isResolvedScheduled = false

    internal private(set) var workSteps = WorkSteps()
//    {
//        didSet {
//            let names = workSteps.values.map({ $0.original.name })
//            print(names.sorted())
//        }
//    }

    
    // MARK: Life-Cycle

    private init() { }
    
    
    // MARK: - Micro Tasks -
    // MARK: Add

    @discardableResult private func addIfNeeded(task: AnyTask) -> WorkStep {
        if workSteps[task: task, phase: .main] == nil {
            workSteps.insert(task: task, phase: .main)
//            let main = workSteps.insert(task: task, phase: .main)
//            let callCompletionHandler = workSteps.insert(task: task, phase: .callCompletionHandler)
//            let cleanUp = workSteps.insert(task: task, phase: .cleanUp)
//            callCompletionHandler.dependencies.insert(<#T##newMember: Dependency##Dependency#>)
        }
        return workSteps[task: task, phase: .main]!
    }
    
    
    private func addDependencies(from task: AnyTask) {
        // Resolve dependencies
        func recursiveAddDependencies(task: AnyTask) {
            guard let thisWorkStep = workSteps[task: task, phase: .main] else { return }
            
            for dependency in thisWorkStep.worker.dependencies {
                let depWorkStep = addIfNeeded(task: dependency.original)
                if depWorkStep.result.isNone {
                    recursiveAddDependencies(task: dependency.original)
                }
            }
        }
        
        recursiveAddDependencies(task: task)
    }

    
    // MARK: Find
    
    private func findUnresolvedWorkSteps() -> [WorkStep] {
        return self.workSteps.values.filter { $0.result.isNone && $0.state == .unresolved }
    }
    
    
    private func findWorkStepsDependingOn(_ searchedTask: AnyTask) -> [WorkStep] {
        return self.workSteps.values.filter { workStep in
            return workStep.dependencies.map({ $0.original }).contains(where: { depTask in
                return depTask.hashValue == searchedTask.hashValue
            })
        }
    }

    
    private func findCompletionHandlersToCall() -> [WorkStep] {
        return self.workSteps.values.filter {
            $0.state == .completed && !$0.worker.completionHandler.isEmpty
        }
    }

    
    private func findCompletedWorkSteps() -> [WorkStep] {
        return self.workSteps.values.filter {
            $0.state == .completed && $0.worker.completionHandler.isEmpty
        }
    }


    private func doWorkStepsExist(dependingOn searchedTask: AnyTask) -> Bool {
        for workStep in workSteps.values {
            for depWorkStep in workStep.dependencies {
                if depWorkStep.original.hashValue == searchedTask.hashValue {
                    return true
                }
            }
        }
        return false
    }

    
    /*
    private func doWorkStepsExist(childOf parentTask: AnyTask) -> Bool {
        for workStep in workSteps.values {
            for depWorkStep in workStep.dependencies {
                if depWorkStep.original.hashValue == parentTask.hashValue && depWorkStep.relationship == .parent {
                    return true
                }
            }
        }
        return false
    }
 */

    
    // MARK: - Main -
    
    public func solve<T: Task>(task: T, then completionBlock: @escaping (T.Result) -> Void) {
        let completionHandler = CompletionHandler { (result) in
            guard let finalResult = result as? T.Result else {
                fatalError("The result type does not match the expected Type (\(T.Result.self))")
            }
            completionBlock(finalResult)
        }
        
        let workStep = addIfNeeded(task: task)
        workStep.worker.completionHandler.append(completionHandler)
        
        setNeedsResolve()
    }


    private func setNeedsResolve() {
        if isResolvedScheduled == false {
            isResolvedScheduled = true
            OperationQueue.main.addOperation { [unowned self] in
                self.isResolvedScheduled = false
                self.resolve()
            }
        }
    }

    
    private func resolve() {
        // Add dependencies of uncompleted work
        for thisWorkStep in findUnresolvedWorkSteps() {
            addDependencies(from: thisWorkStep.original)
        }
        
        // Add dependencies to micro tasks
        for thisWorkStep in findUnresolvedWorkSteps() {
            for dependency in thisWorkStep.worker.dependencies {
                let depTask = TypeErasedTask(anyTask: dependency.original)
                
                if dependency.relationship == .precessor {
                    thisWorkStep.dependencies.insert(depTask)

                } else if dependency.relationship == .parent {
                        thisWorkStep.dependencies.insert(depTask)

                } else if dependency.relationship == .successor, let depWorkStep = workSteps[task: dependency.original, phase: .main] {
                    
                    let thisWorkStepAsDependency = TypeErasedTask(anyTask: thisWorkStep.original)
                    for onThisDepending in findWorkStepsDependingOn(thisWorkStep.original) {
                        guard dependency.original.hashValue != onThisDepending.original.hashValue else { continue }
                        onThisDepending.dependencies.insert(depTask)
                    }
                    
                    depWorkStep.dependencies.insert(thisWorkStepAsDependency)
                }
            }
        }
        
        // Perform work
        obtainResults: for thisWorkStep in findUnresolvedWorkSteps() {
            let dependencies = thisWorkStep.dependencies
            var results = Dependency.Results()
            for dependency in dependencies {
                guard let depWorkSteps = self.workSteps[task: dependency.original, phase: .main], depWorkSteps.result.isObtained else { continue obtainResults }
                results.storage[dependency.hashValue] = depWorkSteps.result.obtainedResult
            }
            
            thisWorkStep.state = .executing
            thisWorkStep.worker.main(results: results, report: { [unowned self] (report, result) in
                switch report {
                case .done:
                    thisWorkStep.result = .obtained(result)
                    thisWorkStep.state = .completed
                default:
                    fatalError()
                }
                self.setNeedsResolve()
                return
            })
        }
        
        // Call completion handlers
        var repeatFinishingTasks = true
        while repeatFinishingTasks {
            repeatFinishingTasks = false
            finishingTasks: for thisWorkStep in findCompletionHandlersToCall() {
                // Check if ALL workers dependencies have been solved
                for dependency in thisWorkStep.worker.dependencies {
                    if self.workSteps[task: dependency.original, phase: .main]?.state != .completed {
                        continue finishingTasks
                    }
                }
                
                // Call completion handlers
                // let hasChildren = doWorkStepsExist(childOf: thisWorkStep.original)
                if thisWorkStep.result.isObtained { // !hasChildren && 
                    let result = thisWorkStep.result.obtainedResult
                    thisWorkStep.worker.completionHandler.forEach { $0.handler(result) }
                    thisWorkStep.worker.completionHandler.removeAll()
                }
                
                // Complete task
                thisWorkStep.dependencies.removeAll()
                thisWorkStep.removeWorker()
                
                // Repeat this for loop so tasks that rely on this task can be
                // completed as well
                repeatFinishingTasks = true

            }
        }
        
        // Remove completed tasks
        var repeatCompletedTasksCleanUp = true
        while repeatCompletedTasksCleanUp {
            repeatCompletedTasksCleanUp = false
            for thisWorkStep in findCompletedWorkSteps() {
                if doWorkStepsExist(dependingOn: thisWorkStep.original) == false {
                    workSteps.remove(workStep: thisWorkStep)
                    repeatCompletedTasksCleanUp = true
                }
            }
        }
    }
}


extension TaskManager {

    class WorkSteps {
        private var steps: [Int: WorkStep]
        
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

        
        func remove(workStep: WorkStep) {
            steps.removeValue(forKey: workStep.hashValue)
        }

        
        var values: Dictionary<Int, WorkStep>.Values {
            return steps.values
        }
        
        
        var isEmpty: Bool {
            return steps.isEmpty
        }
    }
}



extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        TaskManager.shared.solve(task: self, then: completionBlock)
    }
}

