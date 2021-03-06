//
//  WorkerTests.swift
//  Worker
//
//  Created by Karsten Bruns on 11.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation
import XCTest
@testable import WorkerBee

class WorkerTests: XCTestCase {
    func testWithNoDependencies() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil

        TestTask(name: "A").solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A"])
            XCTAssertEqual(result, "A")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testWithPrecessorDependency() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil
        
        let task = TestTask(name: "B", precessors: ["A"])
        
        task.solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A", "B", "/B"])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
   
    
    func testWithSuccessorDependency() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil
        
        let task = TestTask(name: "A", successors: ["B"])

        task.solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A", "B", "/B"])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    
    func testWithDependencies() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil
        
        let task = TestTask(name: "B", precessors: ["A"], successors: ["C"])
        task.solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A", "B", "/B", "C", "/C"])
            // XCTAssertEqual(TestResults.shared.results?[taskA], "A")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    
    func testWithParentDependencies() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil
        
        let task = TestTask(name: "B", successors: ["C"], parents: ["A"])
        
        task.solve { (result) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertEqual(TestResults.shared.executionLog, ["A", "B", "/B", "C", "/C", "/A"])
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }


    func testWithComplexDependencies() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()

        MainTask().solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A", "B", "/B", "C", "/C", "Main", "/Main", "Exit", "/Exit"])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testExecutionDeduplication() {
        let expMain = expectation(description: "Main")
        let expExit = expectation(description: "Exit")
        let expC    = expectation(description: "C")
        let expExec = expectation(description: "Execution")
        TestResults.shared.executionLog.removeAll()
        
        let exitTask = TestTask(name: "Exit")
        let cTask = TestTask(name: "C")
        
        MainTask().solve { (result) in
            XCTAssertEqual(result, "Main")
            expMain.fulfill()
        }
        
        exitTask.solve { (result) in
            XCTAssertEqual(result, "Exit")
            expExit.fulfill()
        }
        
        cTask.solve { (result) in
            XCTAssertEqual(result, "C")
            expC.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "/A", "B", "/B", "C", "/C", "Main", "/Main", "Exit", "/Exit"])
            expExec.fulfill()
        })
        
        wait(for: [expMain, expExit, expC, expExec], timeout: 3)
    }
    
    
    func testTaskRemoval() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        
        MainTask().solve { (result) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                XCTAssertEqual(WorkCoordinator.shared.workSteps.isEmpty, true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    exp.fulfill()
                }
            })
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    static var allTests = [
        ("testWithNoDependencies", testWithNoDependencies),
        ("testWithPrecessorDependency", testWithPrecessorDependency),
        ("testWithSuccessorDependency", testWithSuccessorDependency),
        ("testWithDependencies", testWithDependencies),
        ("testWithParentDependencies", testWithParentDependencies),
        ("testExecutionDeduplication", testExecutionDeduplication),
        ("testWithComplexDependencies", testWithComplexDependencies),
        ("testTaskRemoval", testTaskRemoval),
    ]
}
