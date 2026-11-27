// A user of a client library that imports LinkerSets without re-exporting it: the expansion calls
// LinkerSets' #linkerSetRecord, which this file can't see.
import ImportingClient

enum Probes {
    @Probe
    static let first = 1
}
