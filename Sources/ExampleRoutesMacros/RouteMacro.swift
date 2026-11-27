import ExampleRoutesKind
import LinkerSetsMacroSupport
import SwiftCompilerPlugin

// A client's whole plugin: its macro's kind, and the plugin that offers it. The expansion and its
// diagnostics come from LinkerSetsMacroSupport.

@main
struct ExampleRoutesMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [RouteMacro.self]
}

/// `@Route`: registers a route, a record of kind `"rout"`.
public enum RouteMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { RouteKind.rawValue }
}
