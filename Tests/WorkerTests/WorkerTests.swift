//
//  WorkerTests.swift
//  Worker
//
//  Created by Karsten Bruns on 11.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation
import XCTest
@testable import Worker

class WorkerTests: XCTestCase {
    func testWithNoDependencies() {
        let exp = expectation(description: "")
        
        TaskA().solve { (result) in
            XCTAssertEqual(result, "A")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testWithDependencies() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        TestResults.shared.results = nil
        
        let taskA = TaskA()
        let taskB = TaskB()

        taskB.solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "B", "C"])
            XCTAssertEqual(TestResults.shared.results?[taskA], "A")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    
    func testExecutionDeduplication() {
        let expMain = expectation(description: "Main")
        let expExit = expectation(description: "Exit")
        let expC    = expectation(description: "C")
        let expExec = expectation(description: "Execution")
        TestResults.shared.executionLog.removeAll()

        MainTask().solve { (result) in
            XCTAssertEqual(result, "Main")
            expMain.fulfill()
        }

        ExitTask().solve { (result) in
            XCTAssertEqual(result, "Exit")
            expExit.fulfill()
        }

        TaskC().solve { (result) in
            XCTAssertEqual(result, "C")
            expC.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "B", "C", "Main", "Exit"])
            expExec.fulfill()
        })

        wait(for: [expMain, expExit, expC, expExec], timeout: 3)
    }


    func testMixSuccessorsAndPrecessors() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()

        MainTask().solve { (result) in
            XCTAssertEqual(TestResults.shared.executionLog, ["A", "B", "C", "Main", "Exit"])
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testTaskRemoval() {
        let exp = expectation(description: "")
        TestResults.shared.executionLog.removeAll()
        
        MainTask().solve { (result) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                XCTAssertEqual(TaskManager.shared.workSteps.isEmpty, true)
                exp.fulfill()
            })
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }

    
    static var allTests = [
        ("testWithNoDependencies", testWithNoDependencies),
        ("testWithDependencies", testWithDependencies),
        ("testExecutionDeduplication", testExecutionDeduplication),
        ("testMixSuccessorsAndPrecessors", testMixSuccessorsAndPrecessors),
        ("testTaskRemoval", testTaskRemoval),
    ]
}
