//
//  main.swift
//  Worker
//
//  Created by Karsten Bruns on 08.12.17.
//  Copyright © 2017 Karsten Bruns. All rights reserved.
//


/*
 Use Cases:
 Bluetooth-Manager: Muss initiert und nach allen subtasks deinitiert werden
    - Mindest-Lebenszeit
    - Muss die Anzahl der Bluetooth-Verbindungen (subtasks) bestimmen
 
 Bluetooth-Verbindung: Muss initiert und nach allen subtasks deinitiert werden
     - Mindest-Lebenszeit
     - Muss die paralellen Anfragen auf 1 reduzieren
 
 Suchanfrage an Webserver: Muss gecancelt werden können, wenn Suchbegriffe sich ändert und Anfragen noch geplant sind
 
 Authentifizierung mit Webserver:
    - Session muss aufgebaut werden, bevor request API-Anfrage wird
 
 API-Anfrage:
    - API-Anfragen müssen wiederholt werden können, wenn Authentifizierung invalide ist
 
 

 */

import Foundation







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
    
    override func main(results: [Dependency : Any], report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("A", Array(results.values))
            report(.done("A"))
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
    
    override func main(results: [Dependency : Any], report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("B", Array(results.values))
            report(.done("B"))
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
    
    override func main(results: [Dependency : Any], report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("C", Array(results.values))
            report(.done("C"))
        }
    }
}


struct ExitTask: Task {
    
    typealias Result = String
    
    let name = "Exit"
    let hashValue: Int
    
    init() {
        self.hashValue = name.hashValue
    }
    
    func createWorker() -> AnyWorker {
        return ExitWorker(task: self)
    }
}


class ExitWorker: Worker<ExitTask> {
    
    public required init(task: ExitTask) {
        super.init(task: task)
        add(dependency: TaskB(), as: .precessor)
    }
    
    override func main(results: [Dependency : Any], report: @escaping (Report) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("EXIT", Array(results.values))
            report(.done("EXIT"))
        }
    }
}



ExitTask().solve { (result) in
    print("SOLVED!")
}

ExitTask().solve { (result) in
    print("SOLVED!")
}


DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    print("End")
    exit(0)
}
dispatchMain()


