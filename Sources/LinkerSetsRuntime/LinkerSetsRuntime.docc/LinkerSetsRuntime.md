# ``LinkerSetsRuntime``

Find every record of a kind at run time, without building any macros.

## Overview

LinkerSetsRuntime holds the run-time half of LinkerSets: ``LinkerSet``, which reads every record
of one kind from every loaded image, the ``LinkerSetRecord`` each declaration becomes, and the
``LinkerSetKind`` that tags it. It depends on nothing else, so a module that only reads records
builds no compiler plugin and no swift-syntax.

The LinkerSets module re-exports it beside `@LinkerSetEntry`, so `import LinkerSets` gives both. A
module that writes records with `@LinkerSetEntry` depends on LinkerSets. A module that only reads
them, or a client library whose own macro writes them, depends on LinkerSetsRuntime:

```swift
import LinkerSetsRuntime

let plugins = LinkerSet<Any.Type>(kind: LinkerSetKind(rawValue: 0x706C_7567)).values  // "plug"
```

## Topics

### Finding records

- ``LinkerSet``
- ``LinkerSetRecord``
- ``LinkerSetKind``
