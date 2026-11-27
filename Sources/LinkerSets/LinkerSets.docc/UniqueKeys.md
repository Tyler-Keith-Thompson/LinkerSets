# Unique keys

Make two records of one kind with the same key fail to build, within one executable or library.

## Overview

Records are anonymous bytes in a section, and the linker concatenates them, so two modules can
register the same route or the same event name, and nothing notices until the program reads the
set. The linker does refuse two definitions of one symbol. A record declared with a unique key gets
a function beside it whose symbol is named for the record's kind and the key, so a second
declaration of that kind and key defines the symbol again and the build fails, naming it.

```swift
enum Routes {
    @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/home")
    static let home = Route(path: "/home")
}
```

``LinkerSetEntry(kind:uniqueKey:)`` takes the key as a string literal. A client's own macro gives
each declaration its key from LinkerSetsMacroSupport's `uniqueKey(of:attribute:)`: from the
declaration, such as an event type's name, or from an argument of the attribute through
`uniqueKeyArgument(of:)`. Records of different kinds never clash, because the kind is part of the
symbol's name.

### What the developer sees

The symbol reads `$linkerset_kind_<kind>_key_<key>`: the kind as eight hex digits, then the key,
with ASCII letters and digits as they are and every other UTF-8 byte as `_` and two hex digits. The
route above is `$linkerset_kind_726F7574_key__2Fhome`, and an event named `OrderPlaced` of kind
`"evnt"` is `$linkerset_kind_65766E74_key_OrderPlaced`.

Two declarations in one module are caught by the compiler:

```
error: multiple definitions of symbol '$linkerset_kind_726F7574_key__2Fhome'
```

Two modules linked into one program are caught by the linker, which names both object files. Each
linker words it its own way.

Apple's `ld`:

```
duplicate symbol '_$linkerset_kind_65766E74_key_OrderPlaced' in:
    .../libCheckout.a[2](OrderPlaced.swift.o)
    .../libOrders.a[2](OrderPlaced.swift.o)
ld: 1 duplicate symbols
```

LLVM's `lld` for ELF, which Bazel links with on Linux and Android uses, points at the macro
expansion that declares each one:

```
ld.lld: error: duplicate symbol: $linkerset_kind_65766E74_key_OrderPlaced
>>> defined at @__swiftmacro_6Orders11OrderPlaced5EventfMp_.swift:6
>>>            OrderPlaced.swift.o:($linkerset_kind_65766E74_key_OrderPlaced) in archive libOrders.a
>>> defined at @__swiftmacro_8Checkout11OrderPlaced5EventfMp_.swift:6
>>>            OrderPlaced.swift.o:(.text.$linkerset_kind_65766E74_key_OrderPlaced+0x0) in archive libCheckout.a
```

GNU gold, which `swiftc` links with on Linux by default:

```
/usr/bin/ld.gold: error: ./libCheckout.a(OrderPlaced.swift.o): multiple definition of '$linkerset_kind_65766E74_key_OrderPlaced'
/usr/bin/ld.gold: ./libOrders.a(OrderPlaced.swift.o): previous definition here
```

`wasm-ld`, for WebAssembly:

```
wasm-ld: error: duplicate symbol: $linkerset_kind_65766E74_key_OrderPlaced
>>> defined in .../Orders.objlib/a.o
>>> defined in .../Checkout.objlib/b.o
```

On Windows, `lld-link` and `link.exe` refuse a symbol defined twice as well (`LNK2005` from
`link.exe`), but no test shows it yet.

### One linked image at a time

The check covers the modules linked statically into one executable or one shared library. It
doesn't reach across images:

- Shared libraries and frameworks keep their symbols apart. On Apple platforms each image's
  symbols live in a namespace of their own, and on ELF the first definition the loader finds wins
  without an error. The function is internal, so a library doesn't export it either.
- A library opened with `dlopen` is never compared with the program.

A record of the same key in another image is still read, so a client that needs the guarantee for
the whole process keeps a check at run time too, such as throwing when two records share a name.

### Static archives

A static archive's member is linked only when something references it. Its record and its key's
symbol sit in the same object file, so the two are linked together or not at all: a module whose
records are missing (see <doc:PlatformsAndLinking>) is missing from the check as well.

SwiftPM and Bazel link a target's modules whole, and there a duplicate is an error. Apple's `ld`
makes one exception: with `-dead_strip`, the default for release builds in Xcode, a duplicate from
an archive member read on demand is only a warning, `ld: warning: duplicate symbol`, and the link
succeeds. Link the archive whole (`-force_load`, or `-all_load` for every archive), or make the
linker's warnings errors with `-Xlinker -fatal_warnings`, to keep it an error. Linux's linkers and
`wasm-ld` make it an error either way.

### Where a key can't be checked

A symbol declared inside a `private` or `fileprivate` type, or an extension marked either way, is
local to its file, and the linker never compares local symbols. The macros refuse a unique key
there: "can't check its unique key inside a private or fileprivate type". The enclosing type can be
seen from swift-syntax 600 on. With an older swift-syntax the key in such a type compiles and goes
unchecked. A key that is empty, or a `uniqueKey:` argument that isn't a string literal or holds an
interpolation, is refused too (<doc:WhatTheMacrosRefuse>).

### What is tested where

| Format | Covered by | Runs in |
|---|---|---|
| Mach-O, macOS | `Tests/CompileFailures`: `DuplicateEventNames` (an archive read on demand), `DistinctEventNames`, `DuplicateKeyInOneModule` | `just test` |
| ELF, Linux | The same tests, linked with `lld`; gold checked by hand | CI's Linux Bazel job |
| WebAssembly | Checked by hand with the 6.4.3 SDK's `wasm-ld`; `UniqueKeyRecordTests` reads keyed records | `just wasi-test` |
| COFF, Windows | Untested: `UniqueKeyRecordTests` shows keyed records build and read, but no test links a duplicate | CI's Windows workflow |

The Bazel tests build their programs with `tools/link_test.bzl`, which links outside Bazel's own
link step so that a link meant to fail doesn't fail the build. SwiftPM can't hold such a test: a
package with a duplicate fails to build as a whole.
