@_exported import LinkerSets

// A client's declarations: its kind, and its macro, whose plugin (ExampleRoutesMacros) gives the
// same kind to every record it writes.

extension LinkerSetKind {
    /// Records of routes, `"rout"`.
    public static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}

/// Registers a static ``Endpoint`` property, or a global one, as one of the app's routes.
@attached(peer)
public macro Route() = #externalMacro(module: "ExampleRoutesMacros", type: "RouteMacro")
