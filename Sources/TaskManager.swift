//
//  Solver.swift
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

    internal private(set) var managedTasks = [Int: ManagedTask]()
//    {
//        didSet {
//            let names = managedTasks.values.map({ $0.original.name })
//            print(names.sorted())
//        }
//    }

    
    // MARK: Life-Cycle

    private init() { }
    
    
    // MARK: - Managed Tasks -
    // MARK: Add

    @discardableResult private func addIfNeeded(task: AnyTask) -> ManagedTask {
        if managedTasks[task.hashValue] == nil {
            let managedTask = ManagedTask(original: task)
            managedTasks[task.hashValue] = managedTask
        }
        return managedTasks[task.hashValue]!
    }
    
    
    private func addDependencies(from task: AnyTask) {
        // Resolve dependencies
        func recursiveAddDependencies(task: AnyTask) {
            guard let thisManagedTask = managedTasks[task.hashValue] else { return }
            
            for dependency in thisManagedTask.worker.dependencies {
                let depManagedTask = addIfNeeded(task: dependency.original)
                if depManagedTask.result.isNone {
                    recursiveAddDependencies(task: dependency.original)
                }
            }
        }
        
        recursiveAddDependencies(task: task)
    }

    
    // MARK: Find
    
    private func findUnresolvedManagedTasks() -> [ManagedTask] {
        return self.managedTasks.values.filter { $0.result.isNone && $0.state == .unresolved }
    }
    
    
    private func findManagedTasksDependingOn(_ searchedTask: AnyTask) -> [ManagedTask] {
        return self.managedTasks.values.filter { managedTask in
            return managedTask.dependencies.map({ $0.original }).contains(where: { depTask in
                return depTask.hashValue == searchedTask.hashValue
            })
        }
    }

    
    private func managedTasksExists(dependingOn searchedTask: AnyTask) -> Bool {
        let first = self.managedTasks.values.first { managedTask in
            return managedTask.dependencies.map({ $0.original }).contains(where: { depTask in
                return depTask.hashValue == searchedTask.hashValue
            })
        }
        return first != nil
    }

    
    private func findManagedTasksToFinish() -> [ManagedTask] {
        return self.managedTasks.values.filter {
            ($0.state == .completed && !$0.completionHandler.isEmpty) || $0.state == .resultObtained
        }
    }

    
    private func findCompletedManagedTasks() -> [ManagedTask] {
        return self.managedTasks.values.filter { $0.state == .completed }
    }

    
    // MARK: - Main -
    
    public func solve<T: Task>(task: T, then completionBlock: @escaping (T.Result) -> Void) {
        let completionHandler = ManagedTask.CompletionHandler { (result) in
            guard let finalResult = result as? T.Result else {
                fatalError("The result type does not match the expected Type (\(T.Result.self))")
            }
            completionBlock(finalResult)
        }
        
        let managedTask = addIfNeeded(task: task)
        managedTask.completionHandler.append(completionHandler)
        
        resolve()
    }


    private func resolve() {
        if isResolvedScheduled == false {
            isResolvedScheduled = true
            OperationQueue.main.addOperation { [unowned self] in
                self.isResolvedScheduled = false
                self.resolveImplementation()
            }
        }
    }

    
    private func resolveImplementation() {
        // Add dependencies of unfinished work
        for thisManagedTask in findUnresolvedManagedTasks() {
            addDependencies(from: thisManagedTask.original)
        }
        
        // Add dependencies to managed tasks
        for thisManagedTask in findUnresolvedManagedTasks() {
            for dependency in thisManagedTask.worker.dependencies {
                
                if dependency.relationship == .precessor {
                    thisManagedTask.dependencies.insert(dependency)
                    
                } else if dependency.relationship == .successor, let depManagedTask = managedTasks[dependency.hashValue] {
                    
                    let thisManagedTaskAsDependency = Dependency(anyTask: thisManagedTask.original, relationship: .precessor)
                    for onThisDepending in findManagedTasksDependingOn(thisManagedTask.original) {
                        guard dependency.original.hashValue != onThisDepending.original.hashValue else { continue }
                        onThisDepending.dependencies.insert(dependency)
                    }
                    
                    depManagedTask.dependencies.insert(thisManagedTaskAsDependency)
                }
            }
        }
        
        // Find tasks with all depending tasks solved
        obtainResults: for thisManagedTask in findUnresolvedManagedTasks() {
            let dependencies = thisManagedTask.dependencies
            var results = [Dependency : Any?]()
            for dependency in dependencies {
                guard let depManagedTasks = self.managedTasks[dependency.hashValue], depManagedTasks.result.isObtained else { continue obtainResults }
                results[dependency] = depManagedTasks.result.obtainedResult
            }
            
            thisManagedTask.state = .executing
            
            let worker = thisManagedTask.worker
            worker.main(results: results, report: { [unowned self] (report) in
                switch report {
                case .done(let result):
                    thisManagedTask.result = .obtained(result)
                    thisManagedTask.state = .resultObtained
                default:
                    fatalError()
                }
                self.resolve()
                return
            })
        }
        
        // Finish managed tasks
        var repeatFinishingTasks = true
        while repeatFinishingTasks {
            repeatFinishingTasks = false
            finishingTasks: for thisManagedTask in findManagedTasksToFinish() {
                // Check if ALL workers dependencies have been solved
                for dependency in thisManagedTask.worker.dependencies {
                    if self.managedTasks[dependency.hashValue]?.state != .completed {
                        continue finishingTasks
                    }
                }
                
                // Finish task
                thisManagedTask.state = .completed
                thisManagedTask.dependencies.removeAll()
                thisManagedTask.removeWorker()

                // Repeat this for loop so tasks that rely on this task can be
                // completed as well
                repeatFinishingTasks = true
                
                // Call completion handlers
                if thisManagedTask.result.isObtained {
                    let result = thisManagedTask.result.obtainedResult
                    thisManagedTask.completionHandler.forEach { $0.handler(result) }
                    thisManagedTask.completionHandler.removeAll()
                }
            }
        }
        
        // Remove completed tasks
        var repeatCompletedTasksCleanUp = true
        while repeatCompletedTasksCleanUp {
            repeatCompletedTasksCleanUp = false
            for thisManagedTask in findCompletedManagedTasks() {
                if managedTasksExists(dependingOn: thisManagedTask.original) == false {
                    managedTasks.removeValue(forKey: thisManagedTask.hashValue)
                    repeatCompletedTasksCleanUp = true
                }
            }
        }
    }
}


extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        TaskManager.shared.solve(task: self, then: completionBlock)
    }
}

