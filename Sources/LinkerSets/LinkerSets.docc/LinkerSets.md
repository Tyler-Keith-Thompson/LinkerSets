# ``LinkerSets``

Declarations that register themselves at compile time and are found at run time across every module a program links.

## Overview

An attached macro emits a small record into a section LinkerSets owns, and a typed run-time API
enumerates every record of one kind in a deterministic order. Each record carries a kind, so
clients share the mechanism without seeing each other's records. Failures are typed errors; the
run-time API never traps.

A declaration registers itself with ``LinkerSetEntry(kind:)``, tagged with a kind: four ASCII
characters read as a 32-bit integer. A ``/LinkerSetsRuntime/LinkerSet`` of that kind finds every such declaration
at run time:

```swift
import LinkerSets

enum Routes {
    @LinkerSetEntry(kind: 0x726F_7574)  // "rout"
    static let home = Route(path: "/")
}

let routes = LinkerSet<Route>(kind: LinkerSetKind(rawValue: 0x726F_7574)).values
```

A client that registers one kind of thing can give it a macro with the kind fixed, such as
`@Route`, from its own compiler plugin. The LinkerSetsMacroSupport module's documentation shows
how.

## Topics

### Guides

- <doc:DeclaringAKind>
- <doc:FindingRecords>
- <doc:WhatTheMacrosRefuse>
- <doc:ReplacingARegistry>
- <doc:PlatformsAndLinking>
- <doc:Performance>

### Declaring records

- ``LinkerSetEntry(kind:)``

### Finding records

LinkerSets re-exports ``/LinkerSetsRuntime``, which holds ``/LinkerSetsRuntime/LinkerSet``,
``/LinkerSetsRuntime/LinkerSetRecord`` and ``/LinkerSetsRuntime/LinkerSetKind``. A module that only
reads records depends on LinkerSetsRuntime alone and builds no macros.
