# Replacing a hand-written registry

Move a central list of event types, routes or registrations onto declarations that find
themselves.

## Overview

A registry is a list someone has to keep in step with the code: every analytics event type in an
array, every route in a table, every dependency registered in one function at startup. A new type
that isn't added works everywhere except where the list is read, and nothing tells you. Moving the
list onto LinkerSets takes four steps, and the list is deleted at the end.

Take an analytics library whose events are types conforming to `AnalyticsEvent`, collected by
hand so the library can validate their schemas at launch:

```swift
public protocol AnalyticsEvent {
    static var name: String { get }
}

// Every module's events, listed by hand.
let allEvents: [any AnalyticsEvent.Type] = [
    Login.self,
    Logout.self,
    PurchaseCompleted.self,
]
```

### 1. Give the library a macro

Pick a kind ("evnt" is `0x6576_6E74`, as <doc:DeclaringAKind> explains) and add a compiler plugin
whose macro requires the protocol, so its records hold `any AnalyticsEvent.Type`:

```swift
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Analytics.AnalyticsEvent"
    }
}
```

The library declares the macro and the kind, re-exports LinkerSetsRuntime for the expansion, and
reads the set for its users:

```swift
@_exported import LinkerSetsRuntime

extension LinkerSetKind {
    static let events = LinkerSetKind(rawValue: 0x6576_6E74)  // "evnt"
}

@attached(peer)
public macro Event() = #externalMacro(module: "AnalyticsMacros", type: "EventMacro")

public enum AnalyticsEvents {
    public static var all: [any AnalyticsEvent.Type] {
        LinkerSet<any AnalyticsEvent.Type>(kind: .events).values
    }
}
```

The re-export is required. The expansion lands in each user's file and names
`LinkerSetsRuntime.LinkerSetRecord` there, so that file must see the LinkerSetsRuntime module. A
library that imports it without re-exporting it leaves its users' files failing with "cannot find
'LinkerSetsRuntime' in scope" unless each one imports it too. The library depends on
LinkerSetsRuntime, not LinkerSets: its own plugin writes the records, so it needn't build
LinkerSets' plugin as well. The re-export also puts
``/LinkerSetsRuntime/LinkerSet`` and ``/LinkerSetsRuntime/LinkerSetKind`` in scope wherever the library is imported. Keep the kind
internal and hand users the values through the library's own API (`AnalyticsEvents.all`), so the
set is read in one place.

The LinkerSetsMacroSupport module's documentation has the package targets this needs.

### 2. Read the set beside the list

Before touching any event, read both and compare them, in a test or a debug build:

```swift
let discovered = AnalyticsEvents.all
let missing = allEvents.filter { listed in !discovered.contains { $0 == listed } }
```

`missing` starts as the whole list and shrinks as events are marked.

### 3. Mark each event where it's declared

```swift
@Event
struct Login: AnalyticsEvent {
    static let name = "login"
}
```

An event that doesn't conform fails to compile. A generic event type, or one nested in a generic
type, is refused with a message, as <doc:WhatTheMacrosRefuse> lists; such a type needs its concrete
specializations listed by hand, or a concrete wrapper.

### 4. Delete the list

Once `missing` is empty, the library reads the set instead:

```swift
let allEvents = LinkerSet<any AnalyticsEvent.Type>(kind: .events).values
```

and the hand-written array goes. A new event is registered by writing `@Event` on it, in whichever
module declares it.

### Other registries

The same steps fit any list whose entries can be declared as constants, functions or types:

- **Routes**: `@Route static let profile = Route(path: "/profile")`, read as `LinkerSet<Route>`.
- **Migrations**: `@Migration static func addUsers(_ db: inout Database)`, read as
  `LinkerSet<(inout Database) -> Void>`, sorted by a version the migration declares.
- **Dependency registrations**: `@Registration static func register(_ container: Container)`, each
  module registering its own factories, read and called once at startup.

A registry whose order matters gets it from the entries, never from the set: the linker's order is
stable but not one you choose (<doc:FindingRecords>).
