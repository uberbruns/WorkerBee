# WorkerBee

WorkerBee 🐝 is a work-in-progress/experimental library that explores the idea of managing async tasks by using a dependency resolver. You define a description of a task by creating a type that conforms to the `Task` protocol and a coresponding `Worker<T>` class. The `Task` describes a unit of work and the `Worker` executes it.


## The Task

```swift
struct WaitTask: Task {
    typealias Result = Date
    
    let name = "Wait"
    let hashValue: Int
    let duration: TimeInterval

    func createWorker() -> Any {
        return WaitWorker(task: self)
    }
    
    init(duration: TimeInterval, context: String) {
        self.duration = duration
        self.hashValue = (context + String(duration)).hashValue
    }
}
```

The goal of this task is just to wait for a specified duration and to return the current time (as `Date`) when the waiting time is over. In this example we also define a context string that is used together with the duration as hash. If two tasks with the same hashValue are scheduled at the same time only one worker will execute it, but the result will be given to both callers who created the tasks.


## The Worker

```swift
class WaitWorker: Worker<WaitTask> {
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + task.duration) {
            report(.done, Date())
        }
    }
}
```

The `Worker` is initialized with the `Task` and executes it by using the `main` function. When finished it calls the result `report` closure with `.done` and the result.


## Call Site

If you want to execute a task it would look like this:

```swift
WaitTask(duration: 5, context: "ForIt").solve { now in
    print(now)
}

```


## Interdependent Tasks

A worker can define other tasks that need to be executed before or after itself, by calling the `add(...)` function in its initializer.

```swift
class WaitWorker: Worker<WaitTask> {
    
    public required init(task: WaitTask) {
        super.init(task: task)
        add(dependency: TestTask(name: "Precessor"), as: .precessor)
        add(dependency: TestTask(name: "Successor"), as: .successor)
    }
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + task.duration) {
            report(.done, Date())
        }
    }
}

```

The results of the preceding tasks are available through the `results` attribute of the `main(...)` function.

## Parent/Child Relationship

A dependency relationship cannot only be `.precessor` or `.successor`, it can also be `.parent`. If someone would define `WaitWorker` as its parent, `WaitWorker`s `cleanUp(...)` function would not be called directly after the `main(...)` function, but after the child worker completed its work.


```swift
class WaitWorker: Worker<WaitTask> {
    
    public required init(task: WaitTask) {
        super.init(task: task)
        add(dependency: TestTask(name: "Precessor"), as: .precessor)
        add(dependency: TestTask(name: "Successor"), as: .successor)
    }
    
    override func main(results: Dependency.Results, report: @escaping (Report, Any?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + task.duration) {
            report(.done, Date())
        }
    }
    
    override func cleanUp(report: @escaping (Report) -> Void) {
        // Clean up work
    }
}
```

This is  useful for example if you have a `BluetoothConnection`-task and a `BluetoothMessage`-task. The message task would define the connection as parent and when it is executed the connection task could build up the bluetooth connection in its main function, then the message tasks deliver the messages and when finished the clean up function of the connection tasks closes the connection.



## Todo

- [ ] Error-Handling
- [ ] Cancelation (DisposeBag?)
- [ ] much more
