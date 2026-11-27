// The control for NonConformingEvent: the same declaration, conforming, compiles.
import ExampleEvents

@Event
struct AnEvent: AnalyticsEvent {
    static let name = "an event"
}
