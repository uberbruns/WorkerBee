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
    internal var managedTasks = [Int: ManagedTask]()

    
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
    
    
    private func findManagedTasksByState(_ state: ManagedTask.State) -> [ManagedTask] {
        return self.managedTasks.values.filter { $0.state == state }
    }

    
    // MARK: - Main -
    
    public func solve<T: Task>(task: T, then completionBlock: @escaping (T.Result) -> Void) {
        let completionHandler = ManagedTask.CompletionHandler { (result) in
            guard let result = result as? T.Result else {
                fatalError()
            }
            completionBlock(result)
        }
        
        let managedTask = addIfNeeded(task: task)
        managedTask.completionHandler.append(completionHandler)
        
        resolve()
    }

    
    private func resolve() {
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
        
        // Find tasks with all related task solved
        obtainResults: for thisManagedTask in findUnresolvedManagedTasks() {
            let dependencies = thisManagedTask.dependencies
            var results = [Dependency : Any]()
            for dependency in dependencies {
                guard let result = self.managedTasks[dependency.hashValue]?.result else { continue obtainResults }
                results[dependency] = result
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
            finishingTasks: for thisManagedTask in findManagedTasksByState(.resultObtained) {
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
    }
}


extension Task {
    func solve(then completionBlock: @escaping (Self.Result) -> Void) {
        TaskManager.shared.solve(task: self, then: completionBlock)
    }
}

