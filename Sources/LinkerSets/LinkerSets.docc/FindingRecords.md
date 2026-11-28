# Finding records

Read every declaration of a kind, as the type you expect.

## Overview

A ``/LinkerSetsRuntime/LinkerSet`` names a kind and a type. Its ``/LinkerSetsRuntime/LinkerSet/values`` are the values of every record of
that kind that produces the type:

```swift
let routes = LinkerSet<Route>(kind: .routes).values
```

What you ask for depends on what was marked:

| Marked declaration | Ask for |
|---|---|
| `static let home = Route(path: "/")` | `LinkerSet<Route>` |
| `static func migrate(_ db: inout Database)` | `LinkerSet<(inout Database) -> Void>` |
| `@MainActor static func show()`, or a static func of a `@MainActor` type | `LinkerSet<@MainActor () -> Void>`, read on the main actor |
| `struct Login: AnalyticsEvent`, with `@LinkerSetEntry` | `LinkerSet<Any.Type>` |
| `struct Login: AnalyticsEvent`, with a macro requiring `AnalyticsEvent` | `LinkerSet<any AnalyticsEvent.Type>` |

A record of the right kind but another type is left out of `values`. Nothing traps, and nothing
throws: a set with no matching records is empty.

### Types registered by hand

`@LinkerSetEntry` on a type stores it as `Any.Type`, so a `LinkerSet<any Step.Type>` doesn't find
it. A client macro that requires `Step` stores `any Step.Type`; until there is one (or in tests
that use a kind of their own), mark a static let typed as the existential metatype:

```swift
protocol Step: SendableMetatype {
    static var name: String { get }
}

struct First: Step { static let name = "first" }

enum Steps {
    @LinkerSetEntry(kind: .steps)
    static let first: any Step.Type = First.self
}

let steps = LinkerSet<any Step.Type>(kind: .steps).values
```

`Step` refines `SendableMetatype` because a static let must be `Sendable` in Swift 6, and
`any Step.Type` is `Sendable` only when the protocol says its metatypes are. Without it the
compiler warns that the property isn't concurrency-safe (`MutableGlobalVariable`), which is an
error in a build that treats warnings as errors. A `@MainActor` protocol, such as a UIKit delegate
protocol, refines it the same way.

### Order

Records come back image by image in the order the loader lists them (the program, then its
libraries, then each library loaded later), and within an image in the order the linker laid them
out. The order is stable from one read to the next while nothing new is loaded, but it isn't one
you choose. Sort the values when order matters:

```swift
let migrations = LinkerSet<Migration>(kind: .migrations).values.sorted { $0.version < $1.version }
```

### When records are read

Nothing runs at launch. Each read of `values` or ``/LinkerSetsRuntime/LinkerSet/records`` asks the loader for its
images and walks their records, so a read after `dlopen` includes the new library's records. A read
walks every record of every kind, O(*n*) in their number; keep the result rather than reading it in
a hot loop.

### Records one at a time

``/LinkerSetsRuntime/LinkerSet/records`` gives the records themselves, of the set's kind, before any type is asked
for. ``/LinkerSetsRuntime/LinkerSetRecord/value(as:)`` asks one record for a value and says why it can't produce one:

```swift
for record in LinkerSet<Route>(kind: .routes).records {
    do {
        let route = try record.value(as: Route.self)
        print(route.path)
    } catch .typeMismatch {
        // A record of this kind that holds something else.
    } catch {
        // .emptySlot or .unsupportedVersion: the set already leaves these out.
    }
}
```

A record whose reserved fields aren't zero was written by a newer layout of the library; the set
skips it rather than call an accessor whose contract it doesn't know.

### Records the linker never saw

A record is in the program only if its object file is. SwiftPM, and Bazel for `swift_library`
(whose `alwayslink` defaults to `True`), link every object file of each module a target depends
on, so a module whose only job is to declare records still reaches the program. A build that
links a static archive's members only when something references them leaves such a file out,
even from a module the program calls into. Link it whole: `-force_load` on Apple platforms,
`--whole-archive` on Linux, `alwayslink = True` on a Bazel `cc_library` or `objc_library`.
`-ObjC` isn't enough; <doc:PlatformsAndLinking#Linking-modes> says what it keeps.
