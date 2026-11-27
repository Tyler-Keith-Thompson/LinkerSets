@_exported import LinkerSets

// A client that registers types: its kind, the protocol its types conform to, and its macro, whose
// plugin (ExampleEventsMacros) requires that protocol, so the set reads as `any AnalyticsEvent.Type`.

extension LinkerSetKind {
    /// Records of analytics event types, `"evnt"`. Internal, like ExampleRoutes' kind.
    static let events = LinkerSetKind(rawValue: 0x6576_6E74)
}

/// The example app's event types.
public enum AnalyticsEvents {
    /// Every event type the program declares, in the order ``LinkerSet/values`` gives them.
    public static var all: [any AnalyticsEvent.Type] {
        LinkerSet<any AnalyticsEvent.Type>(kind: .events).values
    }
}

/// An analytics event the example app can send.
public protocol AnalyticsEvent {
    /// The name the event is sent under, such as `"login"`.
    static var name: String { get }
}

/// Registers a struct, enum, class or actor conforming to ``AnalyticsEvent`` as one of the app's
/// events.
@attached(peer)
public macro Event() = #externalMacro(module: "ExampleEventsMacros", type: "EventMacro")
