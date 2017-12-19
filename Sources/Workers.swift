//
//  Workers.swift
//  Worker-iOS
//
//  Created by Karsten Bruns on 18.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation


class Workers {
    var workers = [Int: AnyWorker]()

    init() { }
    
    
    subscript(task: AnyTask) -> AnyWorker {
        if let worker = workers[task.hashValue] {
            return worker
        } else {
            let worker = task.createWorker() as! AnyWorker
            workers[task.hashValue] = worker
            return worker
        }
    }

    
    subscript(step: WorkStep) -> AnyWorker {
        return self[step.original]
    }

    
    func removeUnneededWorkers(keep workStepsHashes: Set<Int>) {
        for (key, _) in workers {
            if !workStepsHashes.contains(key) {
                workers.removeValue(forKey: key)
            }
        }
        
        if workStepsHashes.count != workers.count {
            fatalError()
        }
    }
}
