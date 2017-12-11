//
//  Task.swift
//  Worker
//
//  Created by Karsten Bruns on 09.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//

import Foundation


public protocol AnyTask {
    var name: String { get }
    var hashValue: Int { get }
    func createWorker() -> AnyWorker
}



public protocol Task: AnyTask {
    associatedtype Result
}
