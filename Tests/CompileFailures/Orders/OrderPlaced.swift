import ExampleEvents

// An event whose key, its type's name, Checkout's event shares.

/// An order was placed.
@Event
public struct OrderPlaced: AnalyticsEvent {
    public static let name = "order placed"
}
