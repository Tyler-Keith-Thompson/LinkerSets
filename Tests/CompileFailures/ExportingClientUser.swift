// The control: a user of a client library that re-exports LinkerSets compiles with that import
// alone, and the client's internal kind isn't in its scope.
import ExportingClient

enum Probes {
    @Probe
    static let first = 1
}
