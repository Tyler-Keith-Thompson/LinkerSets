import ExampleEvents

// An event of a name no other module uses, which links beside Orders' event.

/// An order was shipped.
@Event
public struct OrderShipped: AnalyticsEvent {
    public static let name = "order shipped"
}
