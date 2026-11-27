// A client library that re-exports LinkerSetsRuntime, as the LinkerSetsMacroSupport guide shows,
// with its kind kept internal. Its users' files see the module name the expansion uses.
@_exported import LinkerSetsRuntime

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
