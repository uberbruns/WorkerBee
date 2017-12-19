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
    
    
    // MARK: - Micro Tasks -
    // MARK: Add

    private func addAsWorkSteps(task: AnyTask) {
        let main = workSteps[task: task, phase: .main] ?? workSteps.insert(task: task, phase: .main)
        let callCompletionHandler = workSteps[task: task, phase: .callCompletionHandler] ?? workSteps.insert(task: task, phase: .callCompletionHandler)
        callCompletionHandler.dependencies.insert(main)
    }
    
    
    private func addWorkersDependenciesAsWorkSteps(task: AnyTask) {
        // Resolve dependencies
        func recursiveAddDependencies(task: AnyTask) {
            guard let thisWorkStep = workSteps[task: task, phase: .main] else { return }
            let worker = workers[thisWorkStep]
            
            for dependency in worker.dependencies {
                addAsWorkSteps(task: dependency.original)
                let worker = workers[dependency.original]
                if worker.result.isNone {
                    recursiveAddDependencies(task: dependency.original)
                }
            }
            
            worker.dependencyState = .added
        }
        
        recursiveAddDependencies(task: task)
    }

    
    // MARK: Find

    private func findWorkersWithUnresolvedDependencies() -> [AnyWorker] {
        var result = [AnyWorker]()
        for (_, workStep) in self.workSteps.steps {
            guard workStep.phase == .main else { continue }
            let worker = workers[workStep]
            if workers[workStep].dependencyState == .unresolved {
                result.append(worker)
            }
        }
        return result
    }

    
    private func findAddedWithUnresolvedDependencies() -> [AnyWorker] {
        var result = [AnyWorker]()
        for (_, workStep) in self.workSteps.steps {
            guard workStep.phase == .main else { continue }
            let worker = workers[workStep]
            if workers[workStep].dependencyState == .added {
                result.append(worker)
            }
        }
        return result
    }

    
    private func findUnresolvedWorkSteps() -> [WorkStep] {
        return self.workSteps.values.filter {
            let worker = workers[$0]
            return worker.dependencyState == .added && $0.state == .unresolved
        }
    }

    
    private func findWorkStepsToExecute() -> [WorkStep] {
        return self.workSteps.values.filter {
            let worker = workers[$0]
            return worker.dependencyState == .interlinked && $0.state == .unresolved
        }
    }

    
    private func findCompletionHandlersToCall() -> [WorkStep] {
        return self.workSteps.values.filter {
            let worker = workers[$0]
            return $0.state == .resolved && worker.completionHandler.isEmpty
        }
    }

    
    private func findCompletedWorkSteps() -> [WorkStep] {
        return self.workSteps.values.filter {
            let worker = workers[$0]
            return $0.state == .resolved && worker.completionHandler.isEmpty
        }
    }


    private func doWorkStepsExist(dependingOn workStep: WorkStep) -> Bool {
        for workStep in workSteps.values {
            for depWorkStep in workStep.dependencies {
                if depWorkStep.hashValue == workStep.hashValue {
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
        
        addAsWorkSteps(task: task)
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
        
        // Add Workers Dependencies As WorkSteps
        print("Add Workers Dependencies As WorkSteps ...\n")

        for worker in findWorkersWithUnresolvedDependencies() {
            guard worker.dependencyState == .unresolved else { continue }
            addWorkersDependenciesAsWorkSteps(task: worker.anyTask)
        }
        
        // Interlink dependencies
        print("Interlink Dependencies ...\n")

        for thisWorkStep in findUnresolvedWorkSteps() {
            let worker = workers[thisWorkStep]
            
            for dependency in worker.dependencies {
                if dependency.relationship == .precessor && thisWorkStep.phase == .main {
                    let precedingStep = workSteps[task: dependency.original, phase: .callCompletionHandler]!
                    thisWorkStep.dependencies.insert(precedingStep)

                } else if dependency.relationship == .successor && thisWorkStep.phase == .main {
                    let mainWorkStep = thisWorkStep
                    let callCompletionHandlerWorkStep = workSteps[task: thisWorkStep.original, phase: .callCompletionHandler]!
                    let successorWorkStep = workSteps[task: dependency.original, phase: .main]!
                    
                    callCompletionHandlerWorkStep.dependencies.insert(successorWorkStep)
                    successorWorkStep.dependencies.insert(mainWorkStep)
                }
            }
            worker.dependencyState = .interlinked
        }
        

        // Execute WorkSteps
        workSteps.debugPrint()
        print("Execute WorkSteps ...\n")
        
        obtainResults: for thisWorkStep in findWorkStepsToExecute() {
            let worker = workers[thisWorkStep]
            var results = Dependency.Results()
            
            // Iterate over dependencies
            for dependency in thisWorkStep.dependencies {
                // All dependencies resolved?
                if dependency.state != .resolved {
                    continue obtainResults
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
                    default:
                        fatalError("Case not yet implemented")
                    }
                    self.setNeedsResolve()
                    return
                })
                
            case .callCompletionHandler:
                worker.callCompletionHandlers()
                thisWorkStep.state = .resolved
                self.setNeedsResolve()

            default:
                break
            }
        }

        // Remove resolved tasks
        workSteps.debugPrint()
        print("Remove Completed WorkSteps ...\n")

        var repeatCompletedTasksCleanUp = true
        while repeatCompletedTasksCleanUp {
            repeatCompletedTasksCleanUp = false
            for thisWorkStep in findCompletedWorkSteps() {
                if doWorkStepsExist(dependingOn: thisWorkStep) == false {
                    workSteps.remove(thisWorkStep)
                    repeatCompletedTasksCleanUp = true
                }
            }
        }

        // Remove unneeded workers
        let workStepsHashes = Set(workSteps.values.map({ $0.original.hashValue }))
        workers.removeUnneededWorkers(forWorkStepsHashes: workStepsHashes)
        
        // Resolve iteration ended
        workSteps.debugPrint()
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
            print(lines.joined(separator: "\n"))
            print("")
        }
    }
}



extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        TaskManager.shared.solve(task: self, then: completionBlock)
    }
}

