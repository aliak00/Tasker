import XCTest

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

extension TaskerTests {
    static let __allTests = [
        ("testExample", testExample),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AsyncOperationTests.__allTests),
        testCase(LoggerTests.__allTests),
        testCase(RingBufferTests.__allTests),
        testCase(TaskerTests.__allTests),
    ]
}
#endif
