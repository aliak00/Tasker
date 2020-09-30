@testable import Tasker
import XCTest

final class AsyncAwaitTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(AsyncOperation.referenceCounter.value).becomes(0)
            AsyncOperation.referenceCounter.value = 0
        }
    }

    func testAwaitInAsyncShouldComplete() {
        let task = AsyncAwaitSpy { () -> Int in
            let one = try! TaskSpy<Int> { callback in
                sleep(for: .milliseconds(1))
                callback(.success(1))
            }.await()
            let two = try! TaskSpy<Int> { callback in
                sleep(for: .milliseconds(1))
                callback(.success(2))
            }.await()
            return one + two
        }
        task.async()
        ensure(task.completionCallCount).becomes(1)
        ensure(task.completionCallData.data.first?.successValue).becomes(3)
    }

    func testAsyncShouldCallExecute() {
        let task = AsyncAwaitSpy {}
        task.async()
        ensure(task.completionCallCount).becomes(1)
    }

    func testAsyncShouldGetCancelledError() {
        let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
        let handle = task.async()
        handle.cancel()
        ensure(task.completionCallCount).becomes(1)
        XCTAssertErrorEqual(task.completionCallData.data.first?.failureValue, TaskError.cancelled)
    }

    func testAsyncShouldTimeoutAfterDeadline() {
        let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
        let handle = task.async(timeout: .milliseconds(1))
        ensure(task.completionCallCount).becomes(1)
        XCTAssertErrorEqual(task.completionCallData.data.first?.failureValue, TaskError.timedOut)
        ensure(handle.state).becomes(.finished)
    }

    func testAsyncShouldCompleteBeforeTimeout() {
        let task = AsyncAwaitSpy { sleep(for: .milliseconds(1)) }
        let handle = task.async(timeout: .milliseconds(5))
        ensure(task.completionCallCount).becomes(1)
        ensure(handle.state).becomes(.finished)
    }

    func testAsyncShouldCallCompletionOnSpecifiedQueue() {
        let queue = DispatchQueue(label: "Tasker.Tests.AsyncTask")
        let key = DispatchSpecificKey<Void>()
        queue.setSpecific(key: key, value: ())
        let task = AsyncAwaitSpy {}
        task.async(queue: queue) { _ in
            XCTAssertTrue(DispatchQueue.getSpecific(key: key) != nil)
        }
        ensure(task.completionCallCount).becomes(1)
    }

    func testAwaitShouldReturnValue() {
        let task = AsyncAwaitSpy { true }
        let value = try! task.await()
        XCTAssertTrue(value)
        ensure(task.completionCallCount).stays(1)
    }

    func testAwaitShouldTurnAsyncIntoSync() {
        let task = AsyncAwaitSpy { () -> Int in
            sleep(for: .milliseconds(1))
            return 3
        }
        let value = try! task.await()
        XCTAssertEqual(value, 3)
        ensure(task.completionCallCount).stays(1)
    }

    func testAwaitShouldTimeoutAfterDeadline() {
        let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
        var maybeError: Error?
        do {
            try task.await(timeout: .milliseconds(1))
        } catch {
            maybeError = error
        }
        XCTAssertEqual(maybeError! as NSError, TaskError.timedOut as NSError)
        ensure(task.completionCallCount).stays(1)
    }

    func testAwaitShouldFinishBeforeDeadline() {
        let task = AsyncAwaitSpy { sleep(for: .milliseconds(1)) }
        try! task.await(timeout: .milliseconds(10))
        ensure(task.completionCallCount).becomes(1)
    }

    func testAsyncAwaitFreeFunctionsShouldSucceeedWithValue() {
        let awaitValue = try? await { (done: @escaping (Int) -> Void) -> Void in
            DispatchQueue.global(qos: .unspecified).async {
                sleep(for: .milliseconds(10))
                done(5)
            }
        }

        XCTAssertEqual(awaitValue, 5)

        let asyncValue = Atomic<Int?>(nil)

        async(closingOver: 5) { r in
            asyncValue.value = r.successValue
        }

        ensure(asyncValue.value).becomes(5)
    }

    func testAsyncFreeFunction() {
        let asyncValue = Atomic<Int?>(nil)
        async(closingOver: 5) { result in
            asyncValue.value = result.successValue
        }
        ensure(asyncValue.value).becomes(5)
    }

    func testAwaitFreeFunctionsShouldSucceeedWithResult() {
        let f = { (done: @escaping (Result<Int, Error>) -> Void) -> Void in
            done(.success(5))
        }

        XCTAssertEqual(try await(block: f), 5)
    }

    func testAwaitFreeFunctionsShouldFailWithResult() {
        let f = { (done: @escaping (Result<Int, Error>) -> Void) -> Void in
            done(.failure(TaskError.unknown))
        }

        XCTAssertThrowsError(try await(block: f))
    }

    func testAwaitFreeFunctionShouldThrowOnTimeOut() {
        let f = { (done: @escaping (Int) -> Void) -> Void in
            DispatchQueue.global(qos: .unspecified).async {
                sleep(for: .milliseconds(100))
                done(5)
            }
        }

        XCTAssertThrowsError(try await(timeout: .milliseconds(10), block: f))
    }

    func testFreeFunctionShouldAwaitVoidFunction() {
        let val = AtomicInt(0)
        let f: (() -> Void) -> Void = { done in
            val.value = 7
            done()
        }
        try! await(block: f)
        ensure(val.value).becomes(7)
    }

    func testAwaitInAsync() {
        let x = AtomicInt(0)
        async {
            x.value = try! AnyTask { 5 }.await()
        }
        ensure(x.value).becomes(5)
    }

    func testAsyncAwaitStartLater() {
        let task = AsyncAwaitSpy { 7 }
        let handle = task.async(startImmediately: false)
        ensure(task.completionCallCount).stays(0)
        handle.start()
        ensure(task.completionCallCount).becomes(1)
        XCTAssertTrue(task.completionCallData.data.first?.successValue == 7)
    }

//    func testAwaitShouldCallCompletionOnSpecifiedQueue() {
//        let queue = DispatchQueue(label: "Tasker.Tests.AsyncTask")
//        let key = DispatchSpecificKey<Void>()
//        queue.setSpecific(key: key, value: ())
//        let task = AsyncAwaitSpy {
//            print(OperationQueue.current?.underlyingQueue?.label)
//            print(DispatchQueue.getSpecific(key: key))
//        }
//        try! task.await()
//    }
}
