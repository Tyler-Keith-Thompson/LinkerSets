# ``LinkerSetsMacroSupport``

The expansion behind every linker-set macro, for clients that declare a kind and a macro of
their own.

## Overview

`@LinkerSetEntry(kind:)` takes its kind as an argument. A client that registers one kind of
thing (routes, events, migrations) gives it a macro that fixes the kind instead, so its users
write `@Route` and never see a number. That takes three declarations.

The client's compiler plugin, a `.macro` target that depends on this module, names the kind:

```swift
import LinkerSetsMacroSupport
import SwiftCompilerPlugin

@main
struct RoutesMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [RouteMacro.self]
}

public enum RouteMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x726F_7574 }  // "rout"
}
```

The client's library declares the macro and the same kind for reading. It re-exports LinkerSets,
because the expansion names LinkerSets' types in its users' files:

```swift
@_exported import LinkerSets

extension LinkerSetKind {
    public static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}

@attached(peer)
public macro Route() = #externalMacro(module: "RoutesMacros", type: "RouteMacro")
```

Its users then register and find routes:

```swift
enum Endpoints {
    @Route static let home = Endpoint(path: "/")
}

let endpoints = LinkerSet<Endpoint>(kind: .routes).values
```

``LinkerSetMacro`` writes the same record `@LinkerSetEntry` writes, in the same section, and its
diagnostics name the client's attribute (`'@Route' applies to static members only`). Each kind
is a set of its own, so two clients in one program never see each other's records as long as
their kinds differ. Kind 0 is reserved, and the expansion refuses it.

A macro that takes its kind as an argument can return ``LinkerSetMacro/kindArgument(of:)`` from
``LinkerSetMacro/kind(of:)``.

## Topics

### Declaring a macro

- ``LinkerSetMacro``
