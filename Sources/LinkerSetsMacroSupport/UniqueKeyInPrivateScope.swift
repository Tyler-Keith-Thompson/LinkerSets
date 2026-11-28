/// What a ``LinkerSetMacro`` does with a unique key on a declaration inside a `private` or
/// `fileprivate` type or extension, where the symbol that checks the key would be local to its
/// file and the linker would never compare it.
///
/// The rule for what counts as a private scope is the same for both cases: any enclosing type or
/// extension marked `private` or `fileprivate`. It is seen from swift-syntax 600 on; before it,
/// the key is written unchecked under either case.
public enum UniqueKeyInPrivateScope: Sendable {
    /// The declaration is refused with ``LinkerSetMacroDiagnostic/Reason/uniqueKeyInPrivateScope``.
    case refused
    /// The record is written without its key, so it compiles and goes unchecked: for a macro whose
    /// users declare same-named types in private scopes on purpose, such as test fixtures.
    case omitted
}
