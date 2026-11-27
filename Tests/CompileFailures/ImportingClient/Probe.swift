// A client library that imports LinkerSets without re-exporting it, for its own reads. Its users'
// files don't see the module name the macro's expansion uses.
import LinkerSetsRuntime

extension LinkerSetKind {
    /// Internal: only this library reads the set.
    static let probes = LinkerSetKind(rawValue: 0x726F_7574)  // "rout"
}

@attached(peer)
public macro Probe() = #externalMacro(module: "ExampleRoutesMacros", type: "RouteMacro")

/// Every probe the program declares, read where the kind is visible.
public func probeCount() -> Int {
    LinkerSet<Int>(kind: .probes).values.count
}
