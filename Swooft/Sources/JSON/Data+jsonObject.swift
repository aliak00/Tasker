import Foundation

extension Data {
    public func jsonObject() throws -> JSONObject {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions())
        } catch {
            throw JSONError.parse(error)
        }
        guard let unwrappedJson = json as? JSONObject else {
            throw JSONError.notDictionary(json)
        }
        return unwrappedJson
    }
}
