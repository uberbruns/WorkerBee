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
    
    let workSteps = WorkSteps()
    let workers = Workers()
    
    
    // MARK: Life-Cycle
    
    private init() { }
    
    
    // MARK: - WorkSteps -
    // MARK: Add
    
    private func addTaskAsWorkStepsIfNeeded(task: AnyTask) {
        guard workSteps[task: task, phase: .main] == nil else { return }
        
        let main = workSteps.insert(task: task, phase: .main)
        let cleanUp = workSteps[task: task, phase: .cleanUp] ?? workSteps.insert(task: task, phase: .cleanUp)
        let callCompletionHandler = workSteps[task: task, phase: .callCompletionHandler] ?? workSteps.insert(task: task, phase: .callCompletionHandler)
        cleanUp.waits(for: main)
        callCompletionHandler.waits(for: cleanUp)
    }
    
    
    private func addWorkersDependenciesAsWorkSteps(_ worker: AnyWorker) {
        // Resolve dependencies
        func recursiveAddDependencies(worker: AnyWorker) {
            guard worker.dependencyState == .unresolved else {
                print(worker.anyTask.name)
                return
            }
            
            worker.dependencyState = .added
            
            for dependency in worker.dependencies {
                addTaskAsWorkStepsIfNeeded(task: dependency.original)
                let worker = workers[dependency.original]
                if worker.dependencyState == .unresolved {
                    let depWorker = workers[dependency.original]
                    recursiveAddDependencies(worker: depWorker)
                }
            }
            
        }
        recursiveAddDependencies(worker: worker)
    }
    
    
    // MARK: Find
    
    private func forEachWorkerWithUnresolvedDependencies(_ block: (AnyWorker) -> Void) {
        for workStep in self.workSteps.steps.values where workStep.phase == .main {
            let worker = workers[workStep]
            if worker.dependencyState == .unresolved {
                block(worker)
            }
        }
    }
    
    
    private func forEachWorkerWithUnlinkedDependencies(_ block: (AnyWorker) -> Void) {
        for worker in self.workers.workers.values where worker.dependencyState == .added {
            block(worker)
        }
    }
    
    
    private func forEachWorkStepReadyToExecute(_ block: (WorkStep) -> Void) {
        for workStep in self.workSteps.values {
            if workers[workStep].dependencyState == .linked && workStep.state == .unresolved {
                block(workStep)
            }
        }
    }
    
    
    private func forEachCompletedWorkStep(_ block: (WorkStep) -> Void) {
        for workStep in self.workSteps.values where workStep.state == .resolved {
            block(workStep)
        }
    }
    
    
    private func doWorkStepsExist(dependingOn searchedWorkStep: WorkStep) -> Bool {
        for thisWorkStep in workSteps.values {
            for depWorkStep in thisWorkStep.dependencies {
                if depWorkStep.hashValue == searchedWorkStep.hashValue {
                    return true
                }
            }
        }
        return false
    }
    
    
    // MARK: - Main -
    
    public func solve<T: Task>(task: T, then completionBlock: @escaping (T.Result) -> Void) {
        let completionHandler = CompletionHandler { (result) in
            guard let finalResult = result as? T.Result else {
                print("The following result does not match the expected type (\(T.Result.self))")
                dump(result)
                fatalError()
            }
            completionBlock(finalResult)
        }
        
        addTaskAsWorkStepsIfNeeded(task: task)
        
        if let callCompletionHandler = workSteps[task: task, phase: .callCompletionHandler] {
            workers[callCompletionHandler].completionHandler.append(completionHandler)
        }
        
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
        print("# Start resolve iteration ...\n")
        
        // Add workers dependencies to work steps
        workSteps.debugPrint()
        print("Add Workers Dependencies As WorkSteps ...\n")
        
        forEachWorkerWithUnresolvedDependencies { worker in
            addWorkersDependenciesAsWorkSteps(worker)
        }
        
        // Link dependencies
        workSteps.debugPrint()
        print("Link Dependencies ...\n")
        
        forEachWorkerWithUnlinkedDependencies() { worker in
            for dependency in worker.dependencies {
                if dependency.relationship == .precessor {
                    // This 'Main' step waits for preceding 'CallCompletionHandler' step
                    let thisMainStep = workSteps[task: worker.anyTask, phase: .main]!
                    let precedingCallCompletionHandler = workSteps[task: dependency.original, phase: .callCompletionHandler]!
                    thisMainStep.waits(for: precedingCallCompletionHandler)
                    
                } else if dependency.relationship == .successor {
                    // This 'CallCompletionHandler' step waits for successors 'CallCompletionHandler'
                    let thisCallCompletionHandler = workSteps[task: worker.anyTask, phase: .callCompletionHandler]!
                    let successorsCallCompletionHandler = workSteps[task: dependency.original, phase: .callCompletionHandler]!
                    thisCallCompletionHandler.waits(for: successorsCallCompletionHandler)
                    
                    // The successors 'Main' step waits for this 'CleanUp' step
                    let successorMain = workSteps[task: dependency.original, phase: .main]!
                    let thisCleanUpStep = workSteps[task: worker.anyTask, phase: .cleanUp]!
                    successorMain.waits(for: thisCleanUpStep)
                }
            }
            
            worker.dependencyState = .linked
        }
        
        // Execute WorkSteps
        workSteps.debugPrint()
        print("Execute WorkSteps ...\n")
        
        forEachWorkStepReadyToExecute() { thisWorkStep in
            let worker = workers[thisWorkStep]
            var results = Dependency.Results()
            
            // Iterate over dependencies
            for dependency in thisWorkStep.dependencies {
                // All dependencies resolved?
                if dependency.state != .resolved {
                    return
                }
                
                // Fill results
                if thisWorkStep.phase == .main {
                    let depWorker = workers[dependency]
                    if depWorker.result.isObtained, let result = depWorker.result.obtainedResult {
                        results.storage[dependency.original.hashValue] = result
                    }
                }
            }
            
            // All dependencies are resolved, start executing ...
            thisWorkStep.state = .executing
            
            switch thisWorkStep.phase {
            case .main:
                worker.main(results: results, report: { [unowned self] (report, result) in
                    switch report {
                    case .done:
                        worker.result = .obtained(result)
                        thisWorkStep.state = .resolved
                        thisWorkStep.dependencies.removeAll()
                    default:
                        fatalError("Case not yet implemented")
                    }
                    self.setNeedsResolve()
                    return
                })
                
            case .callCompletionHandler:
                worker.callCompletionHandlers()
                thisWorkStep.state = .resolved
                thisWorkStep.dependencies.removeAll()
                self.setNeedsResolve()
                
            case .cleanUp:
                worker.cleanUp(report: { (report) in
                    switch report {
                    case .done:
                        thisWorkStep.state = .resolved
                        thisWorkStep.dependencies.removeAll()
                    default:
                        fatalError("Case not yet implemented")
                    }
                    self.setNeedsResolve()
                    return
                })
            }
            
            // Remove resolved tasks
            workSteps.debugPrint()
            print("Remove Completed WorkSteps ...\n")
            
            var repeatCompletedTasksCleanUp = true
            while repeatCompletedTasksCleanUp {
                repeatCompletedTasksCleanUp = false
                forEachCompletedWorkStep() { thisWorkStep in
                    if doWorkStepsExist(dependingOn: thisWorkStep) == false {
                        workSteps.remove(thisWorkStep)
                        repeatCompletedTasksCleanUp = true
                    }
                }
            }
            
            // Remove unneeded workers
            let validWorkStepsHashValues = Set(workSteps.values.map({ $0.original.hashValue }))
            workers.removeUnneededWorkers(keep: validWorkStepsHashValues)
            
            // Resolve iteration ended
            workSteps.debugPrint()
        }
    }
}


extension TaskManager {
    
    class WorkSteps {
        fileprivate var steps: [Int: WorkStep] {
            didSet {
                debugPrint()
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
        
        
        func debugPrint() {
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
                print("No Work Steps")
            } else {
                print(lines.joined(separator: "\n"))
            }
            print("")
        }
    }
}



extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        TaskManager.shared.solve(task: self, then: completionBlock)
    }
}

