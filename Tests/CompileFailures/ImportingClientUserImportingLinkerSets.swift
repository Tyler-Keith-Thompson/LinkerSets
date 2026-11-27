// A user of a client library that doesn't re-export LinkerSetsRuntime compiles once it imports
// LinkerSets itself, which re-exports it.
import ImportingClient
import LinkerSets

enum Probes {
    @Probe
    static let first = 1
}
