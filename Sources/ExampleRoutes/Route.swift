@_exported import LinkerSets

// A client's declarations: its kind, its macro, whose plugin (ExampleRoutesMacros) gives the same
// kind to every record it writes, and the read of the set. The kind is internal: the re-export
// puts LinkerSet in users' scope, and a public kind would let them read the set past `all`.

extension LinkerSetKind {
    /// Records of routes, `"rout"`.
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}

extension Endpoints {
    /// Every route the program declares, in the order ``LinkerSet/values`` gives them.
    public static var all: [Endpoint] {
        LinkerSet<Endpoint>(kind: .routes).values
    }
}

/// Registers a static ``Endpoint`` property, or a global one, as one of the app's routes.
@attached(peer)
public macro Route() = #externalMacro(module: "ExampleRoutesMacros", type: "RouteMacro")
