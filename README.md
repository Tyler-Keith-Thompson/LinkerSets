# LinkerSets

Swift can't answer "give me every route this program declares" or "every type that is an analytics
event" across modules. The usual workaround is a hand-written list somewhere central that every
new route, event, migration or plug-in has to be added to, and that breaks when someone forgets.

LinkerSets removes the list. You mark each declaration with a macro, and at run time you ask for
everything of that kind:

```swift
import LinkerSets

struct Route: Sendable {
    var path: String
}

enum Routes {
    @LinkerSetEntry(kind: 0x726F_7574)  // "rout"
    static let home = Route(path: "/")

    @LinkerSetEntry(kind: 0x726F_7574)
    static let settings = Route(path: "/settings")
}

let paths = LinkerSet<Route>(kind: LinkerSetKind(rawValue: 0x726F_7574)).values.map(\.path)
// "/" and "/settings", in link order
```

The routes could just as well live in ten different modules. Nothing registers them at startup and
nothing names them; the linker gathers them.

[Documentation](https://tyler-keith-thompson.github.io/LinkerSets/documentation/)

## How it works

A *linker set* is an old C trick (FreeBSD's kernel and Swift Testing both use one). Every module
puts small records into a section of the binary with an agreed name. The linker concatenates
that section from every object file into one array. At run time the program reads the array.

**1. The macro writes a record.** `@LinkerSetEntry` adds a hidden global next to the declaration.
Roughly, `home` above becomes:

```swift
static let home = Route(path: "/")

@section("__DATA_CONST,__linker_sets") @used     // "linker_sets" on ELF
private static let record: LinkerSetRecord.Literal = (
    0x726F_7574,                                  // the kind
    0,
    { outValue, type, _, _ in                     // the accessor: writes Routes.home when asked for a Route
        LinkerSetRecord.__store(Self.home, into: outValue, ifAsked: type)
    },
    0,
    0
)
```

`@section` (SE-0492) puts it in LinkerSets' section. `@used` keeps it there: nothing in the
program refers to the record, so without it the compiler and the linker's dead stripping would
throw it away. The record is a constant, so it costs nothing at launch, and the value is built
only when someone asks for it.

**2. The linker collects them.** Each object file carries its own records. Linking puts them back
to back in one section, whichever modules they came from.

**3. `LinkerSet` reads the section.** On Apple platforms it walks the images the loader has mapped
and reads each one's section with `getsectiondata`. On ELF platforms (Linux, Android) it reads
between `__start_linker_sets` and `__stop_linker_sets`, which the linker defines. It keeps the
records of the requested kind and calls each accessor with the type you asked for. A record of
another type declines, so a `LinkerSet<Route>` never hands you something that isn't a `Route`.

The kind is a 32-bit tag, conventionally four ASCII characters, so separate libraries share the one
section without seeing each other's records. A record is 32 bytes (20 where pointers are 32
bits), laid out like Swift Testing's test-content records, but LinkerSets doesn't depend on Swift
Testing. It reads no runtime metadata,
scans no source and looks up no symbols by name.

## Your own macro

A library that registers one kind of thing gives its users a macro with the kind built in, so they
write `@Route` or `@Event` instead of a number. Its compiler plugin is a few lines on top of
`LinkerSetsMacroSupport`:

```swift
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Events.AnalyticsEvent"
    }
}
```

With a required protocol, `@Event` goes on structs, enums, classes and actors, and the set comes
back typed: `LinkerSet<any AnalyticsEvent.Type>(kind: .events).values`. A type that doesn't
conform is a compile error. The `LinkerSetsMacroSupport` documentation walks through the plugin,
the macro declaration and the kind.

The macros refuse what a record can't hold, at compile time and with a message saying why:
generic functions and types, members of generic types, instance members, protocol requirements
and local declarations. At run time nothing traps. A mismatched request throws a typed error, and
a record from an unknown layout is skipped.

## Platforms

| Platform | Status |
|---|---|
| macOS | Supported: Mach-O, tested in debug and release with `-dead_strip`, across statically linked modules |
| Linux | Supported: ELF, tested in debug and release with `--gc-sections`, across statically linked modules |
| iOS, tvOS, watchOS, visionOS, Mac Catalyst | Same Mach-O reader as macOS; not yet tested on devices or simulators |
| Android, FreeBSD | Same ELF reader as Linux; not yet tested |
| Windows, WebAssembly | Not yet: `LinkerSet` isn't available there |

On ELF, the start and stop symbols bound the records of the image they're linked into, which is
the whole program when it's linked statically, as SwiftPM links on Linux. Records in a shared
library loaded with `dlopen` aren't found yet.

A record reaches the program only if its module's object file is linked. SwiftPM and Bazel's
`swift_library` link every object of a dependency. A build that pulls static-archive members in
only on demand needs `-force_load` (Mach-O) or `--whole-archive` (ELF) for a module nothing
references by name.

## Installation

LinkerSets requires Swift 6.4 and supports macOS 15, iOS 18, tvOS 18, watchOS 11 and visionOS 2
or later. The macros build with any swift-syntax from 509 through 604.

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/LinkerSets", from: "0.0.1"),
],
```

Then add the product to your target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "LinkerSets", package: "LinkerSets"),
]),
```

## Modules

| Module | Holds |
|---|---|
| `LinkerSets` | `@LinkerSetEntry`, which registers a declaration; `LinkerSet`, the records of one kind found at run time; `LinkerSetRecord`, the record each entry is; and `LinkerSetKind`, the kind that tags it |
| `LinkerSetsMacroSupport` | `LinkerSetMacro`, which a client's own macro plugin conforms to, so `@Route` writes the same record with the client's kind |

## Development

Bazel is the development build; SwiftPM is the published package. Both are generated from
`scripts/modules.py`. The first example above is a test in `Tests/LinkerSetsTests`, so it can't
drift from the code.

| Command | Does |
|---|---|
| `just test` | Build and run every test |
| `just verify` | The tests under Bazel and under SwiftPM |
| `just modules` | Regenerate `Package.swift` and every `BUILD.bazel` |
| `just docs` | The DocC site into `.build/docs` |
| `just generate` | An Xcode project from the Bazel graph, in `xcode/` |

`AGENTS.md` describes the layout, the workflow and the house rules in full.

## License

Apache 2.0. See `LICENSE`.
