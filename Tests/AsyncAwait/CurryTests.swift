@testable import Tasker
import XCTest

// Define some dummy objects and functions
private struct Image: Equatable {}
private func loadWebResource(_: String, cb: (Result<String, Error>) -> Void) { cb(.success("data")) }
private func decodeImage(_: String, _: String, cb: (Result<Image, Error>) -> Void) { cb(.success(Image())) }
private func dewarpAndCleanupImage(_: Image, cb: (Result<Image, Error>) -> Void) { cb(.success(Image())) }

final class CurryTests: XCTestCase {
    func tastCurryWithAwait() {
        do {
            let a = try? await(block: curry(loadWebResource)("dataprofile.txt"))
            let b = try? await(block: curry(decodeImage)(a!, "r2"))
            let c = try? await(block: curry(dewarpAndCleanupImage)(b!))
            XCTAssertEqual(c, Image())
        }
    }

    func testCurryWithAsync() {
        func processImageData(cb: (Result<Image, Error>) -> Void) {
            do {
                let a = try await(block: curry(loadWebResource)("dataprofile.txt"))
                let b = try await(block: curry(decodeImage)(a, "r2"))
                let c = try await(block: curry(dewarpAndCleanupImage)(b))
                cb(.success(c))
            } catch {
                cb(.failure(error))
            }
        }

        let result = Atomic<Image?>(nil)
        task(executing: processImageData).async {
            result.value = $0.successValue
        }

        ensure(result.value).becomes(Image())
    }
}
