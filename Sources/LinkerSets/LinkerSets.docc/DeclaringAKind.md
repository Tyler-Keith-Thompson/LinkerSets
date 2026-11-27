# Declaring a kind

Pick the number that tags your declarations, and decide whether your users write it.

## Overview

A kind is a 32-bit number that every record carries. A ``LinkerSet`` of a kind holds the records
declared with that kind and no others, so one program can hold your routes, another library's
analytics events and a third's migrations without any of them seeing the others.

### Choosing the number

Any number other than 0 works. 0 marks an empty slot, and the macros refuse it. The convention is
four ASCII letters that name the thing, read as one byte each: "rout" is `r` `o` `u` `t`, which is
`0x72` `0x6F` `0x75` `0x74`, so the kind is `0x726F_7574`. The letters make it unlikely that two
libraries pick the same number, and they stay readable in a hex dump of the binary. Swift computes
one for you:

```swift
let kind = "rout".utf8.reduce(0) { $0 << 8 | UInt32($1) }  // 0x726F_7574
```

Give the kind a name for the code that reads it:

```swift
extension LinkerSetKind {
    static let routes = LinkerSetKind(rawValue: 0x726F_7574)  // "rout"
}
```

A library that reads the set for its users keeps the name internal: the macro writes the kind as a
number, so its users' files never need it.

### When two libraries pick the same number

No compiler sees every module at once, so nothing can check that a kind is unique. If two libraries
choose the same number, their records land in the same set. A record still hands over its value
only when asked for its own type, so a set of a type your library owns (`Route`, not `String`)
holds only your declarations. Read your records as a type of your own, and a clash costs nothing
but the time to skip the other library's records.

### Writing the kind at each declaration

``LinkerSetEntry(kind:)`` takes the kind as an integer literal. It has to be a literal because the
macro writes it into the binary at compile time; a named constant isn't visible to the macro:

```swift
enum Routes {
    @LinkerSetEntry(kind: 0x726F_7574)  // "rout"
    static let home = Route(path: "/")
}
```

That suits a kind used in a few places. A typo in the number puts the declaration in the wrong
set without any error, though.

### Giving your users a macro

A library that asks its users to register things gives them a macro with the kind built in, so
they write `@Route` and never see the number. The macro lives in a small compiler plugin built on
the LinkerSetsMacroSupport module, whose documentation walks through the plugin, the macro's
declaration and the package's targets. The plugin can also require a protocol of every type it
registers, so `@Event` on a type that isn't an event fails to compile where it's written.
