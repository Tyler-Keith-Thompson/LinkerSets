// An event, keyed by its name, inside a private type: the symbol that checks the key would be
// local to this file, so the linker would never compare it.
import ExampleEvents

private enum Checkout {
    @Event
    struct Placed: AnalyticsEvent {
        static let name = "placed"
    }
}
