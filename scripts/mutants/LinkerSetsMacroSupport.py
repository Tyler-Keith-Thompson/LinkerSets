# Planted bugs for LinkerSetsMacroSupport; run with `just mutate LinkerSetsMacroSupport`. See
# scripts/mutate.py.
#
# Each mutant is Mutant(name, file, old, new), where `old` occurs once in
# Sources/LinkerSetsMacroSupport/<file> (or `nth=` picks one), and mode="stmt" replaces whole
# statements rather than an expression. Every mutant must be caught; one that survives needs a
# test, or a note here saying why it is equivalent.
#
# The spec covers the unique key's expansion so far; the record's own expansion is pinned by the
# same expansion tests and the compile-failure fixtures, and takes mutants when it next changes.

TESTS = ["LinkerSetsMacrosTests"]

L = "LinkerSetMacro.swift"
A = "LinkerSetMacro+UniqueKeyArgument.swift"

MUTANTS = [
    # Whether the function is written, and where.
    Mutant("keyignored", L, 'return ["@_silgen_name(\\(literal: symbol)) @used nonisolated \\(raw: staticKeyword)func \\(name)() {}"]', "return []", mode="stmt"),
    Mutant("emptykeyaccepted", L, "!key.isEmpty", "true"),
    Mutant("privatescopeaccepted", L, "!site.isInPrivateScope", "true"),
    Mutant("neverstatic", L, 'site.isMember ? "static " : ""', '""'),
    Mutant("fileprivateunseen", L, "($0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate))", "$0.name.tokenKind == .keyword(.private)"),

    # The symbol's name: the kind's eight digits, and the key's encoding.
    Mutant("kindprefixkept", L, "kind.hexadecimalLiteral.dropFirst(2)", "kind.hexadecimalLiteral.dropFirst(0)"),
    Mutant("unpaddedbyte", L, '(byte < 0x10 ? "0" : "")', '""'),
    Mutant("punctuationverbatim", L, 'UInt8(ascii: "0")...UInt8(ascii: "9")', 'UInt8(ascii: "0")...UInt8(ascii: "_")'),

    # The uniqueKey: argument.
    Mutant("anylabel", A, '$0.label?.text == "uniqueKey"', "true"),
    Mutant("nonliteralignored", A, "throw LinkerSetMacroDiagnostic(.uniqueKeyNotLiteral, macroName: macroName, at: argument.expression).error", "return nil", mode="stmt"),
]
