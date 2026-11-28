# What the macros refuse

Every declaration a record can't describe is a compile error, with a message that says why.

## Overview

A record is a global constant written at compile time: a kind, and a function that hands back one
concrete value. Anything that would need a value only known at run time, or more than one value,
can't be recorded. `@LinkerSetEntry` and every macro built on LinkerSetsMacroSupport refuse these
where they are written. The messages name the attribute as written, so a client's `@Route` reports
`'@Route' applies to static members only`.

| Written | Message |
|---|---|
| `@LinkerSetEntry(kind: routesKind)` | needs its kind as an integer literal, such as 'kind: 0x726F_7574' |
| `@LinkerSetEntry(kind: 0x1_0000_0000)` | kind must fit in 32 bits |
| `@LinkerSetEntry(kind: 0)` | kind 0 is reserved for empty slots |
| on an initializer, a subscript or a typealias | applies to a static property, a static function, a global variable, a free function, or a struct, enum, class or actor |
| on an instance property or method | applies to static members only: a record has no instance to read |
| on `static let (a, b) = (1, 2)` | applies to a variable with a name, not a tuple pattern |
| on `func make<T>() -> T` | cannot apply to a generic function: a record holds one concrete value |
| on `struct Box<T>` | cannot apply to a generic type: a record holds one concrete type |
| on a static member of `struct Box<T>`, `extension Box<Int>` or `extension Box where T == Int` | cannot apply to a member of a generic type: a record holds one concrete value |
| on a protocol's requirement | cannot apply to a protocol's requirement: a record holds a value, and a requirement has none of its own |
| on `@MainActor static let back`, or a `static var` of a `@MainActor` type | cannot apply to a property isolated to the main actor: a record's accessor is nonisolated and can't read it; mark the property nonisolated, or register a @MainActor function that returns it |
| inside a function, closure or accessor | applies at file scope or in a type, not inside a function, closure or accessor: a record is a global |
| `@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: path)`, or a literal with an interpolation | needs its unique key as a string literal without interpolation, such as 'uniqueKey: "/home"' |
| `@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "")` | needs a unique key that isn't empty |
| a unique key on a member of a `private` or `fileprivate` type or extension | can't check its unique key inside a private or fileprivate type: the symbol that checks it would be local to the file; make the enclosing type internal or wider |

A function isolated to the main actor isn't refused: its record holds it as its isolated type,
`@MainActor () -> Void`, which code on the main actor reads and calls. A `static let` of a
`@MainActor` type is recorded too, since a stored `let` of a Sendable type isn't isolated. The
macros see only a `@MainActor` written on the declaration, its type or its extension. A custom
global actor's attribute looks like any other attribute, and isolation a type takes from a
protocol it conforms to isn't in the syntax at all, so a member isolated either way fails to
compile inside the macro's expansion instead.

A macro that requires a protocol adds one more: a type that doesn't conform fails to compile with
the compiler's own message, "cannot convert value of type 'NotAnEvent.Type' to type
'any AnalyticsEvent.Type'".

The checks of scope (members of generic types, protocol requirements, local declarations, a
unique key in a private type) need
swift-syntax 600 or later, where a macro can see what surrounds it. With an older swift-syntax the
compiler still refuses each of these, inside the expanded code, and a registered type must sit at
file scope.

A plain `extension Box` of a generic `Box` is the one member of a generic type the macros can't
see: the extension doesn't say `Box` is generic. The compiler refuses it inside the expanded code,
with "static stored properties not supported in generic types".

Each of these is pinned by a test that must fail to compile, in `Tests/CompileFailures`.

`#linkerSetRecord(kind:storing:)`, which every one of these macros expands to, checks only its
arguments: the same three kind messages under `'#linkerSetRecord'`, and "needs a 'storing:'
expression" without its value. It writes its record as a static member, so a direct call belongs
in a type or an extension.
