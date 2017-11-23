import Foundation

public typealias JSONObject = [String: Any]

protocol JSONObjectProtocol {
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

    func string(forKey key: Key) throws -> String {
        let value = try self.value(forKey: key)
        guard let string = value as? String else {
            throw JSONError.notString(key)
        }
        return string
    }

    func jsonObject(forKey key: Key) throws -> JSONObject {
        let value = try self.value(forKey: key)
        guard let jsonObject = value as? JSONObject else {
            throw JSONError.notJSONObject(key)
        }
        return jsonObject
    }

    func number(forKey key: Key) throws -> Double {
        let value = try self.value(forKey: key)
        guard let number = value as? Double else {
            throw JSONError.notNumber(key)
        }
        return number
    }

    func jsonArray<T>(of _: T.Type, forKey key: Key) throws -> [T] {
        let value = try self.value(forKey: key)
        guard let array = value as? [T] else {
            throw JSONError.notArrayOf("\(T.self)", forKey: "requiredFields")
        }
        return array
    }

    func boolean(forKey key: Key) throws -> Bool {
        let value = try self.value(forKey: key)
        guard let bool = value as? Bool else {
            throw JSONError.notBoolean(key)
        }
        return bool
    }
}
