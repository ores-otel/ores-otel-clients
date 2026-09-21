public struct Client {
    public let baseUrl: String

    public func healthUrl() -> String {
        return baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/health"
    }
}
