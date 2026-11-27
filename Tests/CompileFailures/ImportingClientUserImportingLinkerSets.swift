// A user of a client library that doesn't re-export LinkerSets compiles once it imports LinkerSets
// itself.
import ImportingClient
import LinkerSets

enum Probes {
    @Probe
    static let first = 1
}
