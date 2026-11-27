// @Event requires AnalyticsEvent: a type without the conformance must not compile.
import ExampleEvents

@Event
struct NotAnEvent {}
