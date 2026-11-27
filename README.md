# LinkerSets

LinkerSets lets Swift declarations register themselves at compile time and be found at run time,
across every module a program links. You won't need a hand-written central list of event types,
routes, dependency registrations, migrations, debug menu items or plug-ins. An attached macro on a
type, static property or function emits a small record into a section the library owns (SE-0492's
`@section`), and a typed run-time API lists every record of one kind in a deterministic order.
Each record is tagged with a kind, so several libraries can use the mechanism without seeing each
other's records. A client defines its own kind and macro on top of LinkerSets in a few lines. The
macros reject what a record can't describe, such as generic declarations, at compile time, and the
run-time API reports failures as typed errors and never traps.

Discovery uses only each object format's documented mechanisms: Mach-O sections through the
loader's image list, ELF and WebAssembly sections through `__start_`/`__stop_` symbols, and COFF
grouped sections. It doesn't scan Swift's runtime metadata, parse source in a build plugin or look
up symbols by name. The goal is to work on every platform Swift supports, in release builds, with
dead stripping, static and dynamic linking, and code loaded later with `dlopen`. Platforms where
that can't be made reliable are documented as unsupported. The record layout matches Swift
Testing's test-content records, but LinkerSets doesn't depend on Swift Testing.

[Documentation](https://tyler-keith-thompson.github.io/LinkerSets/documentation/)

## Installation

LinkerSets requires Swift 6.4 and supports macOS 15, iOS 18, tvOS 18, watchOS 11 and visionOS 2
or later.

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

## Usage

Every example here is a test in `Tests/LinkerSetsTests`, so it cannot drift from the code.

A client tags its records with a kind of its own, four ASCII characters read as a 32-bit integer:

```swift
import LinkerSets

extension LinkerSetKind {
    /// Records of routes, `"rout"`.
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}

let size = MemoryLayout<LinkerSetRecord>.size  // 32 where pointers are 64 bits, 20 where they are 32
```

## Modules

| Module | Holds |
|---|---|
| `LinkerSets` | `LinkerSetRecord`, the record every linker-set entry is, and `LinkerSetKind`, the kind that tags it |

## Development

Bazel is the development build; SwiftPM is the published package. Both are generated from
`scripts/modules.py`.

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
