import LinkerSetsRuntime

/// A path the example app answers.
public struct Endpoint: Hashable, Sendable {
    /// The path, such as `/settings`.
    public let path: String

    /// The endpoint at `path`.
    ///
    /// - Parameter path: The path it answers.
    public init(path: String) {
        self.path = path
    }
}

/// The example app's routes, each registered with ``Route()``.
public enum Endpoints {
    /// The home screen.
    @Route
    public static let home = Endpoint(path: "/")

    /// The settings screen.
    @Route
    public static let settings = Endpoint(path: "/settings")
}
