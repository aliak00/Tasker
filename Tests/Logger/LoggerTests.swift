import Tasker
import XCTest

class LoggerTests: XCTestCase {
    override func tearDown() {
        Logger.shared.waitTillAllLogsTransported()
    }

    func testLoggerShouldLogTagsIfRequested() {
        let tags = ["tag1", "tag2"]
        var log = ""

        let logger = Logger()
        logger.outputTags = true

        logger.addTransport { log += $0 }
        logger.log("something", tags: tags, force: true)

        logger.waitTillAllLogsTransported()

        for tag in tags { XCTAssertNotNil(log.range(of: tag)) }
    }

    func testLoggerShouldNotLogTagsIfNotRequested() {
        let tags = ["tag1", "tag2"]
        var log = ""

        let logger = Logger()
        logger.outputTags = false

        logger.addTransport { log += $0 }
        logger.log("something", tags: tags)

        logger.waitTillAllLogsTransported()

        for t in tags { XCTAssertNil(log.range(of: t)) }
    }

    func testLoggerShouldFilterLogsUnlessTagged() {
        let tag1 = "tag1"
        let tag2 = "tag2"
        let log1 = "\(tag1) log"
        let log2 = "\(tag2) log"

        var log = ""

        let logger = Logger()
        logger.addTransport { log += $0 }
        logger.filterUnless(tag: tag1)
        logger.log(log1, tag: tag1)
        logger.log(log2, tag: tag2)

        logger.waitTillAllLogsTransported()

        XCTAssertNotNil(log.range(of: log1))
        XCTAssertNil(log.range(of: log2))
    }

    func testLoggerShouldFilterLogsIfTagged() {
        let tag1 = "tag1"
        let tag2 = "tag2"
        let log1 = "\(tag1) log"
        let log2 = "\(tag2) log"

        var log = ""

        let logger = Logger()
        logger.addTransport { log += $0 }
        logger.filterIf(tag: tag1)
        logger.log(log1, tag: tag1)
        logger.log(log2, tag: tag2)

        logger.waitTillAllLogsTransported()

        XCTAssertNil(log.range(of: log1))
        XCTAssertNotNil(log.range(of: log2))
    }

    func testLoggerShouldFilterLogsCorrectly() {
        let tag1 = "tag1"
        let tag2 = "tag2"
        let tag3 = "tag3"
        let log1 = "\(tag1) log"
        let log2 = "\(tag2) log"
        let log3 = "\(tag3) log"

        var log = ""

        let logger = Logger()
        logger.addTransport { log += $0 }
        logger.filterIf(tag: tag1)
        logger.filterIf(tag: tag3)
        logger.filterUnless(tag: tag2)
        logger.filterUnless(tag: tag3)
        logger.log(log1, tag: tag1)
        logger.log(log2, tag: tag2)
        logger.log(log3, tag: tag3)

        logger.waitTillAllLogsTransported()

        XCTAssertNil(log.range(of: log1))
        XCTAssertNotNil(log.range(of: log2))
        XCTAssertNil(log.range(of: log3))
    }
}
