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
    func testExample() {
        let exp = expectation(description: "Solve tasks")
        
        MainTask().solve { (result) in
            XCTAssertEqual(TestResults.shared.results, ["A", "B", "C", "Main", "Exit"])
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 4, handler: nil)
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
