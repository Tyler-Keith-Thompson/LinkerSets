import ExampleEvents

// A second module's event under the name Orders' event already has: a program that links both
// fails to link.

/// An order was placed, as the checkout sees it.
@Event
public struct OrderPlaced: AnalyticsEvent {
    public static let name = "checkout order placed"
}
