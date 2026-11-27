# ``LinkerSets``

Declarations that register themselves at compile time and are found at run time across every module a program links.

## Overview

An attached macro emits a small record into a section LinkerSets owns, and a typed run-time API
enumerates every record of one kind in a deterministic order. Each record carries a kind, so
clients share the mechanism without seeing each other's records. Failures are typed errors; the
run-time API never traps.

`import LinkerSets` imports every module. Each module also has its own documentation and can be
imported on its own.

```swift
import LinkerSets

let greeting = try Greeting(name: "Ada").formal().punctuated(with: "!")
print(greeting.text)  // Good day, Ada!
```

## Topics

### Modules

- ``/Greetings``
