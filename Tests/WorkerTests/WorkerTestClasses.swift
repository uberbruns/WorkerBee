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
    var results: Dependency.Results?
    var randomInt = Int(arc4random())
    
    private init() { }
}



struct TestTask: Task {
    
    typealias Result = String
    
    let name: String
    let hashValue: Int
    
    let precessors: [String]
    let successors: [String]
    let parents: [String]

    init(name: String, precessors: [String] = [], successors: [String] = [], parents: [String] = []) {
        var hashValue = TestResults.shared.randomInt
        extendHash(&hashValue, with: name)
        extendHash(&hashValue, with: "pr-" + precessors.joined(separator: "-"))
        extendHash(&hashValue, with: "su-" + successors.joined(separator: "-"))
        extendHash(&hashValue, with: "pa-" + parents.joined(separator: "-"))

        self.hashValue = hashValue
        self.name = name
        self.precessors = precessors
        self.successors = successors
        self.parents = parents
    }
    
    
    func createWorker() -> Any {
        return TestWorker(task: self)
    }
}



class TestWorker: Worker<TestTask> {
    
    public required init(task: TestTask) {
        super.init(task: task)
        
        for precessor in task.precessors {
            let dependency = TestTask(name: precessor)
            self.add(dependency: dependency, as: .precessor)
        }
        
        for successor in task.successors {
            let dependency = TestTask(name: successor)
            self.add(dependency: dependency, as: .successor)
        }

        for parent in task.parents {
            let dependency = TestTask(name: parent)
            self.add(dependency: dependency, as: .parent)
        }
    }
    
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [unowned self] in
            TestResults.shared.executionLog.append(self.task.name)
            report(.done, self.task.name)
        }
    }
    
    
    override func cleanUp(report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [unowned self] in
            TestResults.shared.executionLog.append("/" + self.task.name)
            report(.done)
        }
    }
}



struct MainTask: Task {
    
    typealias Result = String
    
    let name = "Main"
    let hashValue = MainTask.typeHash
    private static let typeHash = Int(arc4random())
    
    func createWorker() -> Any {
        return MainWorker(task: self)
    }
}



class MainWorker: Worker<MainTask> {
    
    public required init(task: MainTask) {
        super.init(task: task)
        add(dependency: TestTask(name: "B", precessors: ["A"], successors: ["C"]), as: .precessor)
        add(dependency: TestTask(name: "Exit"), as: .successor)
    }
    
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        TestResults.shared.executionLog.append("Main")
        report(.done, "Main")
    }
    
    
    override func cleanUp(report: @escaping (Report) -> Void) {
        TestResults.shared.executionLog.append("/Main")
        report(.done)
    }
}



struct SubTask: Task {
    
    typealias Result = String
    
    let name = "SubTask"
    let hashValue = SubTask.typeHash
    private static let typeHash = Int(arc4random())
    
    func createWorker() -> Any {
        return SubWorker(task: self)
    }
}



class SubWorker: Worker<SubTask> {
    
    public required init(task: SubTask) {
        super.init(task: task)
        add(dependency: TestTask(name: "Super"), as: .parent)
    }
    
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TestResults.shared.executionLog.append("SubTask")
            report(.done, "SubTask")
        }
    }
}
