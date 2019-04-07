# Tasker - a task manager with async await

[![CocoaPods Version](https://img.shields.io/cocoapods/v/Tasker.svg?style=flat)](http://cocoadocs.org/docsets/Tasker)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/aliak00/Tasker.svg?branch=master)](https://travis-ci.org/aliak00/Tasker)
[![license](https://img.shields.io/github/license/aliak00/Tasker.svg)](https://github.com/aliak00/Tasker/blob/master/LICENSE)

[Full API docs](https://aliak00.github.io/Tasker/)

* [Quick look](#quick-look)
* [Tasks](#tasks)
    + [Starting a task](#starting-a-task)
    + [Intercepting a task](#intercepting-a-task)
    + [Reacting to a task](#reacting-to-a-task)
    + [Cancelling a task](#cancelling-a-task)
* [Debugging and Logging](#debugging-and-logging)
* [Add-ons](#add-ons)
    + [Async/Await](#asyncawait)
        - [Async/await as free functions over closures.](#asyncawait-as-free-functions-over-closures)
    + [URLInterceptor](#urlinterceptor)
        - [Intercepting and reacting.](#intercepting-and-reacting)

Tasker is a task manager that's built on top of OperationQueue and GCD that has notions of *interception* and *reaction*. `Interceptors` allow you to modify a task before it's executed and also allow you to control the execution of a task (e.g. batch them, hold them, cancel them, etc.). `Reactors` allow you do something in reaction to the a task's completion _before_ the result is passed to the caller (e.g. run a job, requeue the task, cancel the task, etc).

Tasker also comes with some added functionality on top:
* Async and await
* URLSession interception

## Quick look

```swift
// Create a task object
class MyTask: Task {
    typealias SuccessValue = (data: Data?, response: URLResponse?)
    func execute(completion: @escaping CompletionCallback) {
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(data, response))
            }
        }
    }
}

// Run it in one of three ways:

// Await
do {
    let data: MyTask.SuccessValue = try MyTask().await()
} catch {
    // error
}

// Async
MyTask().async { result in
    // got result
}

// TaskManager
TaskManager.shared.add(task: MyTask()) {result in
    // got result
}
```

## Tasks

A task is any unit of work that is to be carried out. It is protocol based and has a main function called `execute` that is called when the task is supposed to be executed. When a task is completed, a callback with a `Result<T, Error>` is called by the implementation of the `Task`.

E.g.
```swift
class DecodeImage: Task {
    ...
    func execute(completion: @escaping Result<DecodedData, Error>) {
        fetchImageData { data in
            do {
                let decodedData = data.decode()
                completion(.success(decodedData))
            } catch {
                completion(.failure(error))
            }
        }
    }
    ...
}
```

Note that tasks are _reference_ types. They must be because they are easier to reason about and they can be intercepted and reacted to so if we made copies and passed them around you'd have to be very careful with state. When a task is finished, the `completion` callback is called with the result of the task.

If for any reason, the task is cancelled, the task's `didCancel` function is called and you are free to handle that as you see fit. For e.g. 

```swift
class DecodeImage: Task {
    ...
    var task: URLSessionTask
    func execute(completion: @escaping Result<Data, Error>) {
        task = URLSession.shared.dataTask(...)
    }
    func didCancel(with error: Error) {
        // Cancel your URLSessionTask
        task.cancel();
    }
    ...
}
```

### Starting a task

To start a task you can either create a `TaskManager` instance or use the default one provided:

```swift
// Create a task
let manager = TaskManager()
manager.add(task: DecodeImage())

// Use the default
TaskManager.shared.add(task: DecodeImage())
```

Tasks are started as soon as you add them. You can also choose to start one later, or after a specific interval:

```swift
// Start a task later:
let handle = TaskManager.shared.add(task: DecodeImage(), startImmediately: false)
// ...
handle.start()

// Start a task after some interval
TaskManager.shared.add(task: DecodeImage(), after: .seconds(30))
```

Everytime you add a task you get back a handle that can start or cancel a task. You can also query the state of a task and each task is given an incremented identifier.

### Intercepting a task

Every task is _intercepted_ before it is executed by the `TaskManager` that owns it. You can control how a task is intercepted by implementing a `TaskInterceptor`, which has one method:

```swift
func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand
```

Intercept is called with a reference to the task that is about to be executed. You can modify the reference to the task and the command you return will determine what happens to the task. One of the parameters is a `currentBatchCount`; this is there because you can `hold` a task, so this tells you how many is held. Useful for batching events to an analytics system for e.g. See the docs for details on `InterceptCommand`.

You enable an interceptor by passing an array of interceptors to a `TaskManager` object upon creation only.

### Reacting to a task

After a task is done executing, it's time for reactors to be called. `TaskReactor`s allow you to re-process a task if the need arises, or cancel a task that you deem unworthy to complete. You enable reactors by passing an array of them to a `TaskManager` object upon creation (just like interceptors).

A reactor is first asked if it is supposed to execute. It is given the task that just completed, the result of that task's execution, and the task handle that owns it. If `TaskReactor.shouldExecute(...)` returns true, then `TaskReactor.execute(...)` function is called.

Every reactor can have its own `TaskReactorConfiguration`, which can control how the `TaskManager` behaves while a reaction is in progress. For example if you want no more tasks to be executed while you are executing the reactor, or if you want to re-execute the task that caused this reaction, after the reactor is done.

### Cancelling a task

Whenever you add a task to a task manager, you get back a handle that is unique to that task. The `TaskHandle` can be used to cancel a task.

```swift
let handle = TaskManager.shared.add(task: DecodeImage(), startImmediately: false)
// ...
handle.cancel()
```

And then `Task.didCancel(...)`  is called in response to that with `TaskError.cancelled`. The `didCancel` method could also be called as a result of other errors.

## Debugging and Logging

Logging facilities are provided by the library for debugging purposes mainly. To enable them you need to add a transport to the shared logger:

```swift
Logger.shared.addTransport { print($0) }
```

The above will log all messages to stdout. There's also a number of filters that can be applied if you want to debug certain parts. The filters revolve around tags and there're a number of redefined tags that the shared logger uses. See `LogTags` in the docs

## Add-ons

A number of additions that are built on top of the shared task manager are also available

### Async/Await

Async await functionality comes out of the box with Tasker. You can execute a `Task` you create directly synchronously or asynchronously by calling the extension `async` or `await` functions on your task:

```swift
do {
    let data = try DecodeImage().await()
} catch {
    //...
}
```

Or:
```swift
DecodeImage().async { result in
    print(result)
}
```

#### Async/await as free functions over closures.

`async` can be called on any expression as an `@autoclosure`:

 ```swift
 async(loadVideoFileSync()) { result in
    switch result {
    case let .success(videoFile):
        break
    case let .failure(error):
        break
 }
 ```

And `await` can be called on any closure that has the following signatures:
* `@escaping (@escaping (T) -> Void) -> Void`
* `@escaping (@escaping () -> Void) -> Void`
* `@escaping (@escaping (Result<T, Error>) -> Void) -> Void`

Each of the closures has a single parameter. One that returns a `T` which is the result of the `await` operation. One that retuns nothing, i.e. `await` returns `Void` and one that returns a `Result<T, Error>` object. If the result is a failure, then `await` throws.

E.g.:

```swift
let number = try? await { (done: @escaping (Int) -> Void) -> Void in
    DispatchQueue.global(qos: .unspecified).async {
        // Do some long running calculation
        done(5) // return 5
    }
}

 XCTAssertEqual(number, 5)
 ```

### URLInterceptor

The idea behind the URLInterceptor is that it creates a URLSession object that is tied to a `TaskManager` so that you can call interceptors and reactors on `URLRequest`s. This is very useful for example if you need to add headers to all your requests that are going out. You simply then add an interceptor that inserts an authorization header. If for e.g. you need to refresh any tokens after a `URLRequest` fails, a reactor can come in handy - requeue the task, fetch a new auth token, and done.

To create a URLInterceor you can optionally pass in a `URLSessionConfiguration` (just as you would when creating a `URLSession` object), and an array of `TaskInterceptor`s and `TaskReactor`s:

```swift
let urlInterceptor = URLInterceptor(interceptors: [MyInterceptor()], reactors: [Myreactors()])
```

And then you use the internal `URLSession` object to make requests

```swift
urlInterceptor.session.dataTask(with: URL(...)) { data, response, error in
    // the URLInterceptorTask that's associated with this will be intercepted and reacted to
    // by MyInterceptor and MyReactor
}
```

#### Intercepting and reacting

The `URLInterceptor` add-on has a type called `URLInterceptorTask` which encapsulates a `URLRequest` object. So this is the `Task` object that you can intercept with a `TaskInterceptor` or react to with a `TaskReactor`:

Here we create a task interceptor that contains a hypothetical user object and adds an authorization header for the user
object whenever the request is going to go out:

```swift
class Interceptor: TaskInterceptor {
    // ...
    func intercept<T>(task: inout T, currentBatchCount _: Int) -> InterceptCommand where T: Task {
        (task as? URLInterceptorTask)?
            .request
            .addValue(self.user.authorization, forHTTPHeaderField: "Authorization")
        return .execute
    }
}
```

And here we have a reactor that also contains a hypothetical user object and performs a OAuth2 token refresh operation when the result is a 401 failure:

```swift
class Reactor: TaskReactor {
    func execute(done: @escaping (Error?) -> Void) {
        // For example one could refresh the authorization tokens here
        user.refreshAuthorizationToken { result in
            switch result {
            case .success:
                done(nil)
            case let .failure(value):
                done(value)
            }
        }

        func shouldExecute<T: Task>(after result: T.Result, from task: T, with _: TaskHandle) -> Bool {
            guard let result = result as? URLInterceptorTask.Result else {
                return false
            }
            // One can return true if there's a 401 UNAUTHORIZED http response code.
            if case let .success(value) = result {
                return value.(response as? HTTPURLResponse)?.statusCode == 401
            }
            return false
        }
    }
```