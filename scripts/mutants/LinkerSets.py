# Planted bugs for LinkerSets; run with `just mutate LinkerSets`. See scripts/mutate.py.
#
# Each mutant is Mutant(name, file, old, new), where `old` occurs once in Sources/LinkerSets/<file>
# (or `nth=` picks one), and mode="stmt" replaces whole statements rather than an expression.
# Every mutant must be caught; one that survives needs a test, or a note here saying why it is
# equivalent to the original.
#
# Known equivalent mutants (they survive by design): none.
#
# Most of this module is the record's layout: stored properties and a tuple typealias, which a
# mutant schema (a run-time switch around an expression or statement) cannot change. The layout
# tests in LinkerSetsTests pin each field's size, stride, alignment and offset instead.

TESTS = ["LinkerSetsTests"]

K = "LinkerSetKind.swift"

MUTANTS = [
    Mutant("kindignored", K, "self.rawValue = rawValue", "self.rawValue = 0", mode="stmt"),
    Mutant("kindoffbyone", K, "self.rawValue = rawValue", "self.rawValue = rawValue &+ 1", mode="stmt"),
]
