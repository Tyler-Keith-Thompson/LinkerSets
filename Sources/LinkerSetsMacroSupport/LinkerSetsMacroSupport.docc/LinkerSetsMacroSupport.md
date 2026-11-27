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

The client's library declares the macro, the same kind, and the read of the set. It re-exports
LinkerSets, because the expansion names LinkerSets' types in its users' files:

```swift
@_exported import LinkerSets

extension LinkerSetKind {
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)  // "rout"
}

@attached(peer)
public macro Route() = #externalMacro(module: "RoutesMacros", type: "RouteMacro")

extension Endpoints {
    public static var all: [Endpoint] {
        LinkerSet<Endpoint>(kind: .routes).values
    }
}
```

Its users then register routes and read them through the library:

```swift
enum Endpoints {
    @Route static let home = Endpoint(path: "/")
}

let endpoints = Endpoints.all
```

### What the re-export exposes

The expansion is written into each user's file and names `LinkerSets.LinkerSetRecord` there, so
that file has to see the LinkerSets module. With `@_exported import LinkerSets` in the client's
library, importing the client is enough. With a plain or `public import`, every user's file fails
to compile with "cannot find 'LinkerSets' in scope" until it imports LinkerSets itself. The
compile tests in `Tests/CompileFailures` (`ExportingClientUser`, `ImportingClientUser` and
`ImportingClientUserImportingLinkerSets`) check each case.

So every file that imports the client also sees `LinkerSet`, `LinkerSetKind` and anything
public the client adds to them. A kind constant doesn't need to be public: the macro writes the
kind as a number, so users' files never name the constant. Keep it internal and give users the
values through the client's own API, as `Endpoints.all` does above. A user can still read the set
by its number, `LinkerSetKind(rawValue: 0x726F_7574)`; an internal constant only keeps it out of
autocomplete and out of the client's public API.

``LinkerSetMacro`` writes the same record `@LinkerSetEntry` writes, in the same section, and its
diagnostics name the client's attribute (`'@Route' applies to static members only`). Each kind
is a set of its own, so two clients in one program never see each other's records as long as
their kinds differ. Kind 0 is reserved, and the expansion refuses it.

### Registering types

A macro attached to a struct, enum, class or actor stores the type's metatype. To read the types
as a protocol they share, without casting, the plugin names that protocol in
``LinkerSetMacro/requiredConformance(of:)``:

```swift
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Events.AnalyticsEvent"
    }
}
```

Each record then holds `any AnalyticsEvent.Type`, read with
`LinkerSet<any AnalyticsEvent.Type>(kind: .events).values`. A type that doesn't conform fails to
compile where it's declared: "cannot convert value of type 'NotAnEvent.Type' to type
'any AnalyticsEvent.Type'". Qualify the protocol with its module so a type of the same name at
the use site can't stand in for it. Without a required protocol, a type's record holds
`Any.Type`.

A registered type can be nested in another from swift-syntax 600 on. Before 600 a macro can't
see where its declaration sits, so the type must be declared at file scope.

A macro that takes its kind as an argument can return ``LinkerSetMacro/kindArgument(of:)`` from
``LinkerSetMacro/kind(of:)``.

### Writing the expansion yourself

``LinkerSetMacro`` supplies the peer `expansion`. A macro that needs more writes its own and
calls ``LinkerSetMacro/recordPeers(of:providingPeersOf:in:)`` from it for the record. That's how
a macro adds the conformance as well, so its users write `@Event struct Login {}` without naming
the protocol. The macro takes an extension role beside the peer:

```swift
public enum EventMacro: LinkerSetMacro, ExtensionMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Events.AnalyticsEvent"
    }

    // The record, as a peer.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try recordPeers(of: node, providingPeersOf: declaration, in: context)
    }

    // The conformance the record requires, as an extension.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type.trimmed): Events.AnalyticsEvent {}")]
    }
}
```

The library declares the macro with both roles:

```swift
@attached(peer)
@attached(extension, conformances: AnalyticsEvent)
public macro Event() = #externalMacro(module: "EventsMacros", type: "EventMacro")
```

A type can then carry data of its own through the protocol (a schema, a name) while the record
holds only its metatype, read as `LinkerSet<any AnalyticsEvent.Type>`.

### Skipping a record instead of refusing it

The expansion refuses what a record can't hold with an error. A macro that would rather skip some
of those (a generic event that its library lists by hand, say) asks
``LinkerSetMacro/refusal(of:providingPeersOf:in:)`` first. It returns a
``LinkerSetMacroDiagnostic`` whose ``LinkerSetMacroDiagnostic/reason`` says why, and whose
``LinkerSetMacroDiagnostic/node`` is where to report it, or `nil` when the declaration can hold a
record:

```swift
public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
) throws -> [DeclSyntax] {
    if let refusal = try refusal(of: node, providingPeersOf: declaration, in: context),
       refusal.reason == .genericType {
        context.diagnose(Diagnostic(node: refusal.node, message: GenericEventNote()))
        return []
    }
    return try recordPeers(of: node, providingPeersOf: declaration, in: context)
}
```

Every other refusal still reaches ``LinkerSetMacro/recordPeers(of:providingPeersOf:in:)``, which
throws it. Where a declaration sits (in a function's body, a protocol or a generic type) is seen
from swift-syntax 600 on; before it those three aren't returned, and the compiler refuses them in
the expansion.

## Topics

### Declaring a macro

- ``LinkerSetMacro``

### Diagnostics

- ``LinkerSetMacroDiagnostic``
