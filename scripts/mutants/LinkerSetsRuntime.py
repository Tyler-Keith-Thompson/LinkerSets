# Planted bugs for LinkerSetsRuntime; run with `just mutate LinkerSetsRuntime`. See scripts/mutate.py.
#
# Each mutant is Mutant(name, file, old, new), where `old` occurs once in Sources/LinkerSetsRuntime/<file>
# (or `nth=` picks one), and mode="stmt" replaces whole statements rather than an expression.
# Every mutant must be caught; one that survives needs a test, or a note here saying why it is
# equivalent to the original.
#
# Known equivalent mutants (they survive by design), left out of the list:
# - Dropping LinkerSet.records' `guard kind != .emptySlot`, or its `$0.accessor != nil` test: on
#   Mach-O, where `just mutate` runs, no image holds a kind-0 record or one with a null accessor
#   (the ELF and Wasm readers' empty-slot markers don't exist there), so the filter that follows
#   already returns nothing for them. The value(as:) failure tests pin the empty-slot error.
#
# The ELF, Wasm and COFF readers aren't compiled on the Mac, so they take no mutants here; their
# walks over hand-built bytes are tested on every platform they build for.
#
# Most of this module is the record's layout: stored properties and a tuple typealias, which a
# mutant schema (a run-time switch around an expression or statement) cannot change. The layout
# tests in LinkerSetsTests pin each field's size, stride, alignment and offset instead.

TESTS = ["LinkerSetsTests"]

K = "LinkerSetKind.swift"
S = "LinkerSet.swift"
R = "LinkerSetRecord.swift"
B = "LinkerSetSection.swift"
M = "LinkerSetSection+MachO.swift"

MUTANTS = [
    Mutant("kindignored", K, "self.rawValue = rawValue", "self.rawValue = 0", mode="stmt"),
    Mutant("kindoffbyone", K, "self.rawValue = rawValue", "self.rawValue = rawValue &+ 1", mode="stmt"),

    # Kind filtering: which records a set holds.
    Mutant("anykind", S, "$0.kind == kind", "true"),
    Mutant("otherkinds", S, "$0.kind == kind", "$0.kind != kind"),
    Mutant("anyversion", S, "$0.isSupportedVersion", "true"),
    Mutant("reserved1ignored", R, "reserved1 == 0 && reserved2 == 0", "reserved2 == 0"),
    Mutant("reserved2ignored", R, "reserved1 == 0 && reserved2 == 0", "reserved1 == 0"),

    # The accessor's type check: a record produces a value only of its own type.
    Mutant("anytype", R, "type.load(as: Any.Type.self) == Value.self", "true"),
    Mutant("othertypes", R, "type.load(as: Any.Type.self) == Value.self", "type.load(as: Any.Type.self) != Value.self"),
    Mutant("neverproduced", R, "produced ? outValue.move() : nil", "nil"),
    Mutant("versionnotthrown", R, "guard isSupportedVersion else { throw .unsupportedVersion }", "", mode="stmt"),

    # Section bounds: every whole record in every image, and nothing past the section.
    Mutant("lastrecorddropped", B, "bytes.count / stride", "max(0, bytes.count / stride - 1)"),
    Mutant("misalignedoffset", B, "index * stride", "index * (stride / 2)"),
    Mutant("halfsection", M, "Int(size)", "Int(size) / 2"),
    Mutant("mainimageonly", M, "_dyld_image_count()", "min(1, _dyld_image_count())"),
]
