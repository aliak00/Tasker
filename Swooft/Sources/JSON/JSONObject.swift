import Foundation

public typealias JSONObject = [String: Any]

public protocol JSONObjectProtocol {
    associatedtype Key
    associatedtype Value
    subscript(_: Key) -> Value? { get }
}

extension Dictionary: JSONObjectProtocol {}

extension JSONObjectProtocol where Key == String, Value == Any {

    private func value(forKey key: Key) throws -> Value {
        guard let value = self[key] else {
            throw JSONError.noKey(key)
        }
        return value
    }

    public func string(forKey key: Key) throws -> String {
        let value = try self.value(forKey: key)
        guard let string = value as? String else {
            throw JSONError.notString(key)
        }
        return string
    }

    public func jsonObject(forKey key: Key) throws -> JSONObject {
        let value = try self.value(forKey: key)
        guard let jsonObject = value as? JSONObject else {
            throw JSONError.notJSONObject(key)
        }
        return jsonObject
    }

    public func number(forKey key: Key) throws -> Double {
        let value = try self.value(forKey: key)
        guard let number = value as? Double else {
            throw JSONError.notNumber(key)
        }
        return number
    }

    public func jsonArray<T>(of _: T.Type, forKey key: Key) throws -> [T] {
        let value = try self.value(forKey: key)
        guard let array = value as? [T] else {
            throw JSONError.notArrayOf("\(T.self)", forKey: "requiredFields")
        }
        return array
    }

    public func boolean(forKey key: Key) throws -> Bool {
        let value = try self.value(forKey: key)
        guard let bool = value as? Bool else {
            throw JSONError.notBoolean(key)
        }
        return bool
    }

    public func data() throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: self, options: .init(rawValue: 0))
        } catch {
            throw JSONError.parse(error)
        }
    }

    public func string() throws -> String {
        guard let string = String(data: try self.data(), encoding: .utf8) else {
            throw JSONError.parse(GenericError.Failed("to convert data to string"))
        }
        return string
    }
}
