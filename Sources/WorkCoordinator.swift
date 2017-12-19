//
//  WorkCoordinator.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


final public class WorkCoordinator {
    
    // MARK: - Manager -
    // MARK: Properties
    
    public static let shared = WorkCoordinator()
    private var isResolvedScheduled = false

    var printLog = false

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
        let invokeCallback = workSteps[task: task, phase: .callback] ?? workSteps.insert(task: task, phase: .callback)
        cleanUp.waits(for: main)
        invokeCallback.waits(for: cleanUp)
    }
    
    
    private func addWorkersDependenciesAsWorkSteps(_ worker: AnyWorker) {
        // Resolve dependencies
        func recursiveAddDependencies(worker: AnyWorker) {
            guard worker.dependencyState == .unresolved else {
                debugLog(worker.anyTask.name)
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
                self.debugLog("The following result does not match the expected type (\(T.Result.self))")
                dump(result)
                fatalError()
            }
            completionBlock(finalResult)
        }
        
        addTaskAsWorkStepsIfNeeded(task: task)
        
        if let invokeCallback = workSteps[task: task, phase: .callback] {
            workers[invokeCallback].completionHandler.append(completionHandler)
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
        debugLog("# Start resolve iteration ...\n")
        
        // Add workers dependencies to work steps
        workSteps.printDebugInfo()
        debugLog("Add Workers Dependencies As WorkSteps ...\n")
        
        forEachWorkerWithUnresolvedDependencies { worker in
            addWorkersDependenciesAsWorkSteps(worker)
        }
        
        // Link dependencies
        workSteps.printDebugInfo()
        debugLog("Link Dependencies ...\n")
        
        forEachWorkerWithUnlinkedDependencies { worker in
            // Handle parent dependencies
            var parentCleanUpSteps = [WorkStep]()
            for dependency in worker.dependencies where dependency.relationship == .parent {
                // Simplify names
                let childTask = worker.anyTask
                let parentTask = dependency.original
                
                // The child's 'MainStep' step waits for parents 'MainStep' step
                let childMainStep = workSteps[task: childTask, phase: .main]!
                let parentMainStep = workSteps[task: parentTask, phase: .main]!
                childMainStep.waits(for: parentMainStep)
                
                // The parent's 'CleanUp' step waits for the child's 'CleanUp' step
                let childCleanUp = workSteps[task: childTask, phase: .cleanUp]!
                let parentCleanUp = workSteps[task: parentTask, phase: .cleanUp]!
                parentCleanUp.waits(for: childCleanUp)
                
                // Fill parent clean up steps array
                parentCleanUpSteps.append(parentCleanUp)
            }
            
            // Handle remaining dependencies
            for dependency in worker.dependencies {
                if dependency.relationship == .precessor {
                    // Simplify names
                    let thisTask = worker.anyTask
                    let precessorsTask = dependency.original

                    // This 'MainStep' step waits for preceding 'Callback' step
                    let thisMainStep = workSteps[task: thisTask, phase: .main]!
                    let precessorsCallback = workSteps[task: precessorsTask, phase: .callback]!
                    thisMainStep.waits(for: precessorsCallback)
                    
                } else if dependency.relationship == .successor {
                    // Simplify names
                    let thisTask = worker.anyTask
                    let successorTask = dependency.original

                    // This 'Callback' step waits for successors 'Callback'
                    let thisCallback = workSteps[task: thisTask, phase: .callback]!
                    let successorsCallback = workSteps[task: successorTask, phase: .callback]!
                    thisCallback.waits(for: successorsCallback)
                    
                    // The successor's 'MainStep' step waits for this 'CleanUp' step
                    let successorsMainStep = workSteps[task: successorTask, phase: .main]!
                    let thisCleanUp = workSteps[task: thisTask, phase: .cleanUp]!
                    successorsMainStep.waits(for: thisCleanUp)
                    
                    // Parents `CleanUp` steps wait for successors 'Callback'
                    for parentCleanUp in parentCleanUpSteps {
                        parentCleanUp.waits(for: successorsCallback)
                    }
                }
            }
            
            worker.dependencyState = .linked
        }
        
        // Execute WorkSteps
        workSteps.printDebugInfo()
        debugLog("Execute WorkSteps ...\n")
        
        forEachWorkStepReadyToExecute { thisWorkStep in
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
                    worker.result = .obtained(result)
                    thisWorkStep.state = .resolved
                    thisWorkStep.dependencies.removeAll()
                    self.setNeedsResolve()
                    return
                })
                
            case .callback:
                worker.invokeCallbacks()
                thisWorkStep.state = .resolved
                thisWorkStep.dependencies.removeAll()
                self.setNeedsResolve()
                
            case .cleanUp:
                worker.cleanUp(report: { (report) in
                    thisWorkStep.state = .resolved
                    thisWorkStep.dependencies.removeAll()
                    self.setNeedsResolve()
                    return
                })
            }
            
            // Remove resolved tasks
            workSteps.printDebugInfo()
            debugLog("Remove Completed WorkSteps ...\n")
            
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
            workSteps.printDebugInfo()
        }
    }
}



extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        WorkCoordinator.shared.solve(task: self, then: completionBlock)
    }
}

