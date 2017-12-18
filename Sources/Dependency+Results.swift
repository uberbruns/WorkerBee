//
//  DependencyResults.swift
//  Worker-iOS
//
//  Created by Karsten Bruns on 18.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation

extension Dependency {
    
    public struct Results {
        
        var storage: [Int: Any]
        
        init() {
            self.storage = [Int: Any]()
        }
        
        public subscript<T: Task>(_ task: T) -> T.Result? {
            if let result = storage[task.hashValue] as? T.Result {
                return result
            } else {
                return nil
            }
        }
    }
}
