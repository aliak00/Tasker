import XCTest

extension AsyncAwaitTests {
    static let __allTests = [
        ("testAsyncShouldCallCompletionOnSpecifiedQueue", testAsyncShouldCallCompletionOnSpecifiedQueue),
        ("testAsyncShouldCallExecute", testAsyncShouldCallExecute),
        ("testAsyncShouldGetCancelledError", testAsyncShouldGetCancelledError),
        ("testAsyncShouldTimeoutAfterDeadline", testAsyncShouldTimeoutAfterDeadline),
        ("testAwaitShouldReturnValue", testAwaitShouldReturnValue),
        ("testAwaitShouldTimeoutAfterDeadline", testAwaitShouldTimeoutAfterDeadline),
        ("testAwaitShouldTurnAsyncIntoSync", testAwaitShouldTurnAsyncIntoSync),
        ("testShouldWork", testShouldWork),
    ]
}

extension AsyncOperationTests {
    static let __allTests = [
        ("testAddingOperationsToAQueueShouldAllGoToFinished", testAddingOperationsToAQueueShouldAllGoToFinished),
        ("testAddingOperationsToAQueueShouldAllGoToFinishedIfCancelled", testAddingOperationsToAQueueShouldAllGoToFinishedIfCancelled),
        ("testCancellingAfterExecutingShouldCallFinish", testCancellingAfterExecutingShouldCallFinish),
        ("testCancellingBeforeBeforeStartingShouldNotCallExecutor", testCancellingBeforeBeforeStartingShouldNotCallExecutor),
        ("testCancellingBeforeBeforeStartingShouldNotCallFinish", testCancellingBeforeBeforeStartingShouldNotCallFinish),
        ("testCreatingOperationShouldStartInReadyState", testCreatingOperationShouldStartInReadyState),
        ("testStartingOperationShouldCallExecutor", testStartingOperationShouldCallExecutor),
        ("testStartingOperationShouldGoToExecuting", testStartingOperationShouldGoToExecuting),
        ("testStartingOperationShouldGoToFinished", testStartingOperationShouldGoToFinished),
    ]
}

extension LoggerTests {
    static let __allTests = [
        ("testLoggerShouldFilterLogsCorrectly", testLoggerShouldFilterLogsCorrectly),
        ("testLoggerShouldFilterLogsIfTagged", testLoggerShouldFilterLogsIfTagged),
        ("testLoggerShouldFilterLogsUnlessTagged", testLoggerShouldFilterLogsUnlessTagged),
        ("testLoggerShouldLogTagsIfRequested", testLoggerShouldLogTagsIfRequested),
        ("testLoggerShouldNotLogTagsIfNotRequested", testLoggerShouldNotLogTagsIfNotRequested),
    ]
}

extension RingBufferTests {
    static let __allTests = [
        ("testRingBufferShouldEqualAnotherSimilar", testRingBufferShouldEqualAnotherSimilar),
        ("testRingBufferShouldProvideAccurateCount", testRingBufferShouldProvideAccurateCount),
        ("testRingBufferShouldWrapAppends", testRingBufferShouldWrapAppends),
    ]
}

extension TaskHandleTests {
    static let __allTests = [
        ("testCancelShouldCancelATask", testCancelShouldCancelATask),
        ("testStartShouldStartATask", testStartShouldStartATask),
    ]
}

extension TaskManagerTests {
    static let __allTests = [
        ("testAddingATaskShouldCallCompletionCallback", testAddingATaskShouldCallCompletionCallback),
        ("testAddingATaskShouldCallCompletionCallbackAfterGivenInterval", testAddingATaskShouldCallCompletionCallbackAfterGivenInterval),
        ("testAddingATaskShouldExecuteIt", testAddingATaskShouldExecuteIt),
        ("testAddingATaskShouldNotExecuteIfNotToldTo", testAddingATaskShouldNotExecuteIfNotToldTo),
        ("testAddingManyTasksShouldCallAllCallbacks", testAddingManyTasksShouldCallAllCallbacks),
        ("testAddingManyTasksShouldExecuteAllTasks", testAddingManyTasksShouldExecuteAllTasks),
        ("testAddingManyTasksShouldMakeAllHandlesFinished", testAddingManyTasksShouldMakeAllHandlesFinished),
    ]
}

extension TaskerTests {
    static let __allTests = [
        ("testExample", testExample),
    ]
}

extension URLInterceptorTests {
    static let __allTests = [
        ("testShould", testShould),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AsyncAwaitTests.__allTests),
        testCase(AsyncOperationTests.__allTests),
        testCase(LoggerTests.__allTests),
        testCase(RingBufferTests.__allTests),
        testCase(TaskHandleTests.__allTests),
        testCase(TaskManagerTests.__allTests),
        testCase(TaskerTests.__allTests),
        testCase(URLInterceptorTests.__allTests),
    ]
}
#endif
