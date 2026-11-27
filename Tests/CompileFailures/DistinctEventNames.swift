// The control for DuplicateEventNames: Orders and Shipping declare events of different names, so
// the program links and reads both records.
import ExampleEvents
import Orders
import Shipping

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// Shipping's archive is read on demand: this reference brings in the member that holds its record.
let shipped: any AnalyticsEvent.Type = Shipping.OrderShipped.self
let names = AnalyticsEvents.all.map { $0.name }
guard names.contains(Orders.OrderPlaced.name), names.contains(shipped.name) else {
    print("Records read: \(names)")
    exit(1)
}
