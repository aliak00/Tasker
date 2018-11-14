public struct GenericError {}

extension GenericError {
    public struct CannotComply: Error {}
}

extension GenericError {
    public struct Failed: Error, CustomStringConvertible {
        public let description: String
        public init(_ string: String = "failed") {
            self.description = string
        }
    }
}
