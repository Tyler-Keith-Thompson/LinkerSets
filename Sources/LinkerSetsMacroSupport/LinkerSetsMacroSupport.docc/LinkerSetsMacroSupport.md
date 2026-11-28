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

The client's library declares the macro, the same kind, and the read of the set. It depends on
LinkerSets and re-exports it, because the expansion calls LinkerSets' `#linkerSetRecord` in its
users' files:

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

`@Route static let home = ...` expands, in the user's file, to one call:
`#linkerSetRecord(kind: 0x726F7574, storing: Routes.home)`. That macro, which LinkerSets declares,
expands in turn to the record itself, one declaration per object format, naming
`LinkerSetsRuntime.LinkerSetRecord`. So the user's file has to see LinkerSets. With
`@_exported import LinkerSets` in the client's library, importing the client is enough. With a
plain or `public import`, every user's file fails to compile with "no macro named
'linkerSetRecord'" until it imports LinkerSets itself. The compile tests in `Tests/CompileFailures` (`ExportingClientUser`, `ImportingClientUser` and
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

### Checking keys are unique

A macro can give each declaration a key that no other record of its kind in the same executable
or library may share, in ``LinkerSetMacro/uniqueKey(of:attribute:)``. The expansion then adds a
function whose symbol is named for the kind and the key, and a second declaration with the same
key fails to compile in one module, or to link across modules:

```swift
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func uniqueKey(of declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> String? {
        declaration.asProtocol(NamedDeclSyntax.self)?.name.text
    }
}
```

A macro whose users write the key returns ``LinkerSetMacro/uniqueKeyArgument(of:)``, which reads a
`uniqueKey:` string literal. An empty key, and a key on a member of a private type, are refused
with diagnostics of their own. The check reaches one linked image only; LinkerSets' guide to unique
keys shows each linker's message and the limits.

### Declaring the kind once

The plugin returns the kind from ``LinkerSetMacro/kind(of:)`` and the library reads the set by
it, so the number appears twice, and a mismatch shows only at run time, as an empty set. To write
it once, put it in a module of its own that depends on nothing, and have both import it:

```swift
// RoutesKind
public enum RouteKind {
    public static let rawValue: UInt32 = 0x726F_7574  // "rout"
}
```

```swift
// RoutesMacros, the plugin
public enum RouteMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { RouteKind.rawValue }
}
```

```swift
// Routes, the library
extension LinkerSetKind {
    static let routes = LinkerSetKind(rawValue: RouteKind.rawValue)
}
```

The package lists the module among both targets' dependencies:
`.macro(name: "RoutesMacros", dependencies: ["RoutesKind", ...])` and
`.target(name: "Routes", dependencies: ["RoutesKind", "RoutesMacros", ...])`. SwiftPM builds it
for the host for the plugin and for the target for the library.

### Writing records without depending on LinkerSets

A module that uses `@LinkerSetEntry` depends on LinkerSets, which builds LinkerSets' own plugin,
LinkerSetsMacros, and swift-syntax with it. A module that only writes a few records, such as the
events of one feature, can skip that. A client with a plugin of its own declares two macros there:
an entry macro that takes the kind as an argument, as `@LinkerSetEntry` does, and a record macro
of its own under a different name, which the entry macro's expansion calls in place of
`#linkerSetRecord`:

```swift
// DiscoveryMacros, the plugin
@main
struct DiscoveryMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [DiscoverableMacro.self, DiscoverableRecordMacro.self]
}

public enum DiscoverableMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) throws -> UInt32 {
        try kindArgument(of: attribute)
    }

    public static var recordMacroName: String { "discoverableRecord" }
}

public enum DiscoverableRecordMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try LinkerSetRecordMacro.expansion(of: node, in: context)
    }
}
```

The library declares both and re-exports LinkerSetsRuntime, whose names the record uses:

```swift
// Discovery, the library
@_exported import LinkerSetsRuntime

@attached(peer)
public macro Discoverable(kind: UInt32) = #externalMacro(module: "DiscoveryMacros", type: "DiscoverableMacro")

@freestanding(declaration)
public macro discoverableRecord<Value>(kind: UInt32, storing value: Value) = #externalMacro(module: "DiscoveryMacros", type: "DiscoverableRecordMacro")
```

A module that writes records then depends on `Discovery` and `LinkerSetsRuntime`, not on
LinkerSets, and writes `@Discoverable(kind: 0x7365_7373)` where it would have written
`@LinkerSetEntry(kind: 0x7365_7373)`. Its build holds the client's plugin, which already
needs swift-syntax, and not LinkerSetsMacros. The record macro's name must differ from
`linkerSetRecord`, because a module that imports both LinkerSets and the client couldn't choose
between two macros of the same name.

### Testing the expansion

A client's expansion tests pin one line per record, the `#linkerSetRecord` call:

```swift
assertMacroExpansion(
    """
    enum Endpoints {
        @Route
        static let home = Endpoint(path: "/")
    }
    """,
    expandedSource: """
    enum Endpoints {
        static let home = Endpoint(path: "/")

        #linkerSetRecord(kind: 0x726F7574, storing: Endpoints.home)
    }
    """,
    macroSpecs: ["Route": MacroSpec(type: RouteMacro.self)],
    failureHandler: { Issue.record("\($0.message)") }
)
```

`assertMacroExpansion` expands only the macros in its table, so the call stays as written, and it
reads the same on every swift-syntax from 600 on. The record behind it, one declaration per object
format, belongs to LinkerSets and changes when LinkerSets adds a format. A test that wants it
anyway adds `"linkerSetRecord": MacroSpec(type: LinkerSetRecordMacro.self)` to the table. A
declaration at file scope expands to the call inside a private enum of its own, whose name comes
from the context's unique names (`__macro_local_15linkerSetRecordfMu_`).

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

A member declared in an extension of a generic type is refused only when the extension shows the
type is generic: by naming generic arguments (`extension Box<Int>`, `extension [Int]`) or with a
`where` clause. A plain `extension Box` of `struct Box<T>` reads like an extension of any other
type, because the macro sees the extension's syntax and not `Box`'s declaration. No refusal is
returned for it, and the compiler fails inside the expansion with "static stored properties not
supported in generic types". A client macro whose users might write one can say so in its own
docs.

## Topics

### Declaring a macro

- ``LinkerSetMacro``
- ``LinkerSetRecordMacro``

### Diagnostics

- ``LinkerSetMacroDiagnostic``
