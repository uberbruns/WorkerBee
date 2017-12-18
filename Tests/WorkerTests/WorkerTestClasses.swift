//
//  WorkerTestClasses.swift
//  Worker
//
//  Created by Karsten Bruns on 11.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation
@testable import Worker


class TestResults {
    static let shared = TestResults()
    var executionLog = [String]()
    private init() { }
}



struct TaskA: Task {
    
    typealias Result = String
    
    let name = "A"
    let hashValue: Int
    
    
    init() {
        self.hashValue = name.hashValue
    }
    
    
    func createWorker() -> AnyWorker {
        return WorkerA(task: self)
    }
}



class WorkerA: Worker<TaskA> {
    
    public required init(task: TaskA) {
        super.init(task: task)
    }
    
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("A")
            report(.done, "A")
        }
    }
}



struct TaskB: Task {
    
    typealias Result = String
    
    let name = "B"
    let hashValue: Int
    
    
    init() {
        self.hashValue = name.hashValue
    }
    
    
    func createWorker() -> AnyWorker {
        return WorkerB(task: self)
    }
}



class WorkerB: Worker<TaskB> {
    
    public required init(task: TaskB) {
        super.init(task: task)
        add(dependency: TaskA(), as: .precessor)
        add(dependency: TaskC(), as: .successor)
    }
    
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("B")
            report(.done, "B")
        }
    }
    
    
    override func cleanUp(report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("B (CleanUp)")
            report(.done)
        }
    }
}



struct TaskC: Task {
    
    typealias Result = String
    
    let name = "C"
    let hashValue: Int
    
    init() {
        self.hashValue = name.hashValue
    }
    
    
    func createWorker() -> AnyWorker {
        return WorkerC(task: self)
    }
}



class WorkerC: Worker<TaskC> {
    
    public required init(task: TaskC) {
        super.init(task: task)
    }
    
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("C")
            report(.done, "C")
        }
    }
}


struct MainTask: Task {
    
    typealias Result = String
    
    let name = "Main"
    let hashValue = MainTask.typeHash
    private static let typeHash = Int(arc4random())
    
    func createWorker() -> AnyWorker {
        return MainWorker(task: self)
    }
}



class MainWorker: Worker<MainTask> {
    
    public required init(task: MainTask) {
        super.init(task: task)
        add(dependency: TaskB(), as: .precessor)
        add(dependency: ExitTask(), as: .successor)
    }
    
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        TestResults.shared.executionLog.append("Main")
        report(.done, "Main")
    }
}



struct SubTask: Task {
    
    typealias Result = String
    
    let name = "SubTask"
    let hashValue = SubTask.typeHash
    private static let typeHash = Int(arc4random())
    
    func createWorker() -> AnyWorker {
        return SubWorker(task: self)
    }
}



class SubWorker: Worker<SubTask> {
    
    public required init(task: SubTask) {
        super.init(task: task)
        add(dependency: TaskA(), as: .parent)
    }
    
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("SubTask")
            report(.done, "SubTask")
        }
    }
}



struct ExitTask: Task {
    
    typealias Result = String
    
    let name = "Exit"
    let hashValue = ExitTask.typeHash
    private static let typeHash = Int(arc4random())
    
    func createWorker() -> AnyWorker {
        return ExitWorker(task: self)
    }
}



class ExitWorker: Worker<ExitTask> {
    
    public required init(task: ExitTask) {
        super.init(task: task)
    }
    
    override func main(results: [Dependency : Any], report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("Exit")
            report(.done, "Exit")
        }
    }
}
