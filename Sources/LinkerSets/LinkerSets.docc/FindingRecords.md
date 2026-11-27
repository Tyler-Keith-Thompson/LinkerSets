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

A record is in the program only if its module is. SwiftPM and Bazel link every module a target
depends on, so a module whose only job is to declare records still reaches the program. A build
that links a static library's members only when something calls into them leaves such a module
out. Link it whole: `-force_load` on Apple platforms, `--whole-archive` on Linux.
