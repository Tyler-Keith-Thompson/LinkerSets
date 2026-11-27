// A user of a client library that imports LinkerSets without re-exporting it: the expansion names
// LinkerSets' types, and this file can't see the module.
import ImportingClient

enum Probes {
    @Probe
    static let first = 1
}
