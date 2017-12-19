//
//  WorkCoordinator+Logging.swift
//  Worker-iOS
//
//  Created by Karsten Bruns on 19.12.17.
//  Copyright © 2017 Worker. All rights reserved.
//

import Foundation

extension WorkCoordinator {
    
    func debugLog(_ string: String...) {
        guard printLog else { return }
        print(string.joined(separator: "; "))
    }
}
