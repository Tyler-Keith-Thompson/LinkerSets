// The routes kind as a number, in a module of its own that depends on nothing, so the plugin
// (built for the host) and the library (built for the target) both import it and can't disagree.
// A mismatch would only show at run time, as an empty set.

/// The kind of the records `@Route` writes, `"rout"`.
public enum RouteKind {
    /// The kind's value, four ASCII characters read as a 32-bit integer.
    public static let rawValue: UInt32 = 0x726F_7574
}
