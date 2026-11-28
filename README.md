# LinkerSets

LinkerSets gives Swift automatic discovery. You write a declaration anywhere in your program, in
any module, mark it with a macro, and at run time you can ask for every declaration marked the
same way. Nothing has to register it, and no central list has to name it.

This is how test frameworks find your tests: you write `@Test` and the runner finds the function
without you listing it anywhere. LinkerSets lets you do the same with your own kinds of things:
routes, debug menu items, analytics events, database migrations, plug-ins, dependency
registrations. Adding one is a matter of writing it. Forgetting to add it to a list can't happen,
because there's no list.

[Documentation](https://tyler-keith-thompson.github.io/LinkerSets/documentation/)

## Using it

Say every feature module can contribute items to a debug menu, and the menu should show all of
them:

```swift
struct DebugMenuItem: Sendable {
    var title: String
}
```

**1. Pick a kind.** A kind is a number that tags your declarations so they can be found again,
and kept apart from other libraries' declarations. Any 32-bit number other than 0 works, as long
as you use the same one where you declare and where you look up, and nothing else in the program
uses it. The convention is to pick four letters that name the thing and read them as a number,
one byte per letter: "menu" is `m` `e` `n` `u`, which is `0x6D` `0x65` `0x6E` `0x75`, so the kind
is `0x6D65_6E75`. The letters make collisions with other libraries unlikely, and the number is
still readable when it turns up in a hex dump. To compute one in Swift:

```swift
let kind = "menu".utf8.reduce(0) { $0 << 8 | UInt32($1) }  // 0x6D65_6E75
```

Nothing can check at compile time that a kind is unique, because each module is compiled on its
own. If two libraries pick the same number, their records land in the same set. What keeps them
apart is the type you ask for: a record hands over its value only when asked for its own type, so
a set of a type your library owns (`DebugMenuItem` here, not `String`) still holds only your
declarations. Two libraries that share a kind *and* ask for the same type see each other's values.

Give the kind a name for the code that reads it:

```swift
extension LinkerSetKind {
    static let debugMenu = LinkerSetKind(rawValue: 0x6D65_6E75)  // "menu"
}
```

**2. Mark each declaration** with `@LinkerSetEntry` and the kind. The macro needs the number
written out as a literal, because it's checked and baked in at compile time:

```swift
// In the networking module:
enum NetworkDebugging {
    @LinkerSetEntry(kind: 0x6D65_6E75)
    static let clearCache = DebugMenuItem(title: "Clear cache")
}

// In the accounts module:
enum AccountDebugging {
    @LinkerSetEntry(kind: 0x6D65_6E75)
    static let signOut = DebugMenuItem(title: "Sign out")
}
```

**3. Ask for them** with a `LinkerSet` of that kind and the type you expect:

```swift
let items = LinkerSet<DebugMenuItem>(kind: .debugMenu).values
// Both items, in the order the linker laid them out. Sort them if order matters.
```

You get back only values of the type you asked for. A declaration of the same kind but another
type is left out.

### What you can mark

- A static property or a global variable: you get its value.
- A static or free function: you get the function, as a value of its type. A
  `static func migrate(_ db: inout Database)` is found by `LinkerSet<(inout Database) -> Void>`.
- A struct, enum, class or actor: you get the type itself. With `@LinkerSetEntry` that's an
  `Any.Type`; with your own macro (below) it can be `any YourProtocol.Type`.

The macro refuses, at compile time and with a message saying why, anything it can't record:
generic functions and types, members of a generic type, instance members (there's no instance to
read them from), protocol requirements, and declarations inside a function.

## Your own macro

Writing `@LinkerSetEntry(kind: 0x6D65_6E75)` everywhere is noisy, and a typo in the number silently
puts a declaration in the wrong set. A library usually gives its users a macro of its own with the
kind built in, so they write `@DebugMenuItem` or `@Event` and never see the number.

That macro lives in a small compiler plugin on top of `LinkerSetsMacroSupport`. Here's one for
analytics events. Its kind is "evnt" (`e` `v` `n` `t`, `0x65` `0x76` `0x6E` `0x74`), picked the
same way as "menu" above, and it requires every type it's put on to conform to `AnalyticsEvent`:

```swift
public enum EventMacro: LinkerSetMacro {
    public static func kind(of attribute: AttributeSyntax) -> UInt32 { 0x6576_6E74 }  // "evnt"

    public static func requiredConformance(of attribute: AttributeSyntax) -> TypeSyntax? {
        "Events.AnalyticsEvent"
    }
}
```

Users then write `@Event struct Login: AnalyticsEvent { ... }`, and the library reads every event
type with `LinkerSet<any AnalyticsEvent.Type>(kind: .events).values`, already typed, no casting.
Putting `@Event` on a type that doesn't conform is a compile error. The
`LinkerSetsMacroSupport` documentation walks through the plugin, the macro declaration and the
package setup.

## How it works

You don't need this to use the library, but it explains the rules above.

The macro adds a small hidden constant next to your declaration: a record holding the kind and a
function that hands back your value when asked for the right type. The compiler is told to put
that constant in a named section of the binary that LinkerSets owns, and to keep it even though no
code refers to it.

When the program is linked, the linker gathers that section from every module into one place.
At run time, `LinkerSet` reads the section of every loaded image (the program and its libraries)
through the operating system's documented loader APIs, keeps the records of the kind you asked
for, and asks each for a value of your type.

That's why the kind has to be a literal (it's written into the binary), why records survive
release builds and dead stripping (they're marked to be kept), and why discovery costs nothing at
launch (nothing runs until you ask). This technique is called a *linker set*. FreeBSD's kernel
uses it to find drivers, and Swift Testing uses one to find tests. LinkerSets' records have the
same layout as Swift Testing's, but the library doesn't depend on it.

## In a large app

Records cost nothing at launch. Reading a set is one pass over the records, linear in how many
there are, so an app with thousands of events, routes or plug-ins reads them all in a few
milliseconds. Read each set once at startup and keep the array. Each marked declaration adds a
few milliseconds to a debug build. The
[Performance](https://tyler-keith-thompson.github.io/LinkerSets/documentation/linkersets/performance)
guide has the measurements and `just benchmark` repeats them.

## Platforms

| Platform | Status |
|---|---|
| macOS | Supported and tested, in debug and release builds, across static and dynamic libraries and ones loaded later with `dlopen` |
| Linux | Supported and tested, in debug and release builds, across static and dynamic libraries and ones loaded later with `dlopen` |
| iOS, tvOS, watchOS, visionOS, Mac Catalyst | Tested in the iOS, tvOS, watchOS and visionOS simulators and on Mac Catalyst; built for watchOS devices, including the 32-bit arm64_32 |
| Android | Tested on an aarch64 emulator, in debug and release builds, across static libraries and ones loaded later with `dlopen` |
| WebAssembly (WASI) | Supported and tested under wasmtime, in debug and release builds; a WebAssembly program is one statically linked module |
| Windows | Supported and tested in CI (`windows-latest`), across statically linked modules |

A record is only in the program if its object file is. SwiftPM, and Bazel for `swift_library`,
link every object file of each module a target depends on. A build that takes a static archive's
members only when something references them needs `-force_load` (Apple platforms) or
`--whole-archive` (Linux) for an archive that declares records; `-ObjC` isn't enough. The
[Platforms and linking](https://tyler-keith-thompson.github.io/LinkerSets/documentation/linkersets/platformsandlinking)
article has the details.

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

A module that writes records, with `@LinkerSetEntry` or a macro of its own, depends on
`LinkerSets`. A module that only reads them depends on `LinkerSetsRuntime` instead. It holds
`LinkerSet` and has no macros, so it doesn't build swift-syntax.

## Modules

| Module | Holds |
|---|---|
| `LinkerSets` | `@LinkerSetEntry`, which marks a declaration, with `LinkerSetsRuntime` re-exported |
| `LinkerSetsRuntime` | `LinkerSet`, which finds every declaration of a kind; `LinkerSetKind`; and `LinkerSetRecord`, the record each mark becomes. No macros, so no swift-syntax |
| `LinkerSetsMacroSupport` | `LinkerSetMacro`, for writing your own macro with the kind built in |

## Development

Bazel is the development build; SwiftPM is the published package. Both are generated from
`scripts/modules.py`. The examples under "Using it" are tests in `Tests/LinkerSetsTests`, so they
can't drift from the code.

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
