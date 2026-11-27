/// Declares a record of `kind` whose value is this declaration's.
///
/// Attach it to a static property, a global variable, a static function or a free function. The
/// macro adds a `@used` peer, placed with `@section` in the section LinkerSets owns, whose
/// accessor produces the variable's value, or the function itself as a value of its function
/// type. A ``LinkerSet`` of the same kind and value type finds it at run time:
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
/// `func f(_ x: Int) -> String` is found by `LinkerSet<(Int) -> String>`.
///
/// - Parameter kind: The kind the record is tagged with, as an integer literal.
@attached(peer)
public macro LinkerSetEntry(kind: UInt32) = #externalMacro(module: "LinkerSetsMacros", type: "LinkerSetEntryMacro")
