import LinkerSetsRuntime

// At file scope: before swift-syntax 600 a macro can't see whether a type is nested, and the
// package builds with every swift-syntax from 509 on.

/// A user signed in.
@Event
public struct Login: AnalyticsEvent {
    public static let name = "login"
}

/// A user signed out.
@Event
public enum Logout: AnalyticsEvent {
    public static let name = "logout"
}

/// A purchase completed.
@Event
public final class Purchase: AnalyticsEvent {
    public static let name = "purchase"
}

/// A purchase was refunded.
@Event
public actor Refund: AnalyticsEvent {
    public static let name = "refund"
}
