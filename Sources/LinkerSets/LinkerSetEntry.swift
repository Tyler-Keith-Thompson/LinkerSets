/// Declares a record of `kind` whose value is this declaration's.
///
/// Attach it to a static property, a global variable, a static function, a free function, or a
/// struct, enum, class or actor that isn't generic, at file scope or in a type that isn't
/// generic. Anything else is a compile-time error that says why. The macro adds a `@used` peer, placed with
/// `@section` in the section LinkerSets owns, whose accessor produces the variable's value, the
/// function itself as a value of its function type, or the type's metatype as `Any.Type`. A
/// ``/LinkerSetsRuntime/LinkerSet`` of the same kind and value type finds it at run time:
///
/// ```swift
/// enum Routes {
///     @LinkerSetEntry(kind: 0x726F_7574)
///     static let home = Route(path: "/")
/// }
///
/// let routes = LinkerSet<Route>(kind: LinkerSetKind(rawValue: 0x726F_7574)).values
/// ```
///
/// The kind is an integer literal from 1 through `UInt32.max`; kind 0 is reserved for empty
/// slots. A record produces its value only for a request of exactly its type: a function
/// `func f(_ x: Int) -> String` is found by `LinkerSet<(Int) -> String>`, and a type by
/// `LinkerSet<Any.Type>`. A client whose types share a protocol reads them as `any P.Type` through
/// a macro of its own that requires it (LinkerSetsMacroSupport's `LinkerSetMacro`).
///
/// A module that uses it depends on LinkerSets, so its build includes LinkerSets' macro plugin,
/// LinkerSetsMacros, and swift-syntax. A client with a plugin of its own can give its modules an
/// entry macro that writes the same records on LinkerSetsRuntime alone:
/// [Writing records without depending on LinkerSets](https://tyler-keith-thompson.github.io/LinkerSets/documentation/linkersetsmacrosupport#Writing-records-without-depending-on-LinkerSets).
///
/// - Parameter kind: The kind the record is tagged with, as an integer literal.
@attached(peer)
public macro LinkerSetEntry(kind: UInt32) = #externalMacro(module: "LinkerSetsMacros", type: "LinkerSetEntryMacro")

/// Declares a record of `kind` whose value is this declaration's, and that no other record of
/// `kind` in the same executable or library may share `uniqueKey` with.
///
/// The record is the one ``LinkerSetEntry(kind:)`` writes. Beside it the macro declares a function
/// whose symbol is named for the kind and the key, so a second declaration with the same key fails
/// to build: in one module the compiler refuses it, and across modules the linker reports a
/// duplicate symbol, `$linkerset_kind_726F7574_key__2Fhome`, naming both object files:
///
/// ```swift
/// enum Routes {
///     @LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/home")
///     static let home = Route(path: "/home")
/// }
/// ```
///
/// The check covers one linked image. Shared libraries and code loaded with `dlopen` keep their
/// symbols apart, so a key repeated in another image goes unreported:
/// <doc:UniqueKeys> says where it holds on each platform.
///
/// - Parameters:
///   - kind: The kind the record is tagged with, as an integer literal.
///   - uniqueKey: The key, as a string literal that isn't empty and holds no interpolation.
@attached(peer)
public macro LinkerSetEntry(kind: UInt32, uniqueKey: String) = #externalMacro(module: "LinkerSetsMacros", type: "LinkerSetEntryMacro")

/// Declares a record of `kind` whose accessor stores `value`: what every linker-set macro's
/// expansion calls.
///
/// `@LinkerSetEntry` and a client's own macro (LinkerSetsMacroSupport's `LinkerSetMacro`) check
/// the declaration they're attached to and expand to one call of this, so a client's expansion
/// tests pin that call alone. The record it writes, one declaration per object format, is
/// LinkerSets' to change. At file scope the record is a global; in a type or an extension it is a
/// static member, and `value` names the declaration through its enclosing type, `Routes.home`, in
/// a class or an actor as in a struct.
///
/// - Parameters:
///   - kind: The kind the record is tagged with, as an integer literal from 1 through
///     `UInt32.max`.
///   - value: The expression the record's accessor produces, of exactly the type a
///     ``/LinkerSetsRuntime/LinkerSet`` reads it as.
@freestanding(declaration)
public macro linkerSetRecord<Value>(kind: UInt32, storing value: Value) = #externalMacro(module: "LinkerSetsMacros", type: "LinkerSetRecordMacro")
