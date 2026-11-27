# ``LinkerSets``

Declarations that register themselves at compile time and are found at run time across every module a program links.

## Overview

An attached macro emits a small record into a section LinkerSets owns, and a typed run-time API
enumerates every record of one kind in a deterministic order. Each record carries a kind, so
clients share the mechanism without seeing each other's records. Failures are typed errors; the
run-time API never traps.

A client tags its records with a kind of its own, four ASCII characters read as a 32-bit integer:

```swift
import LinkerSets

extension LinkerSetKind {
    /// Records of routes, `"rout"`.
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)
}
```

## Topics

### Records

- ``LinkerSetRecord``
- ``LinkerSetKind``
