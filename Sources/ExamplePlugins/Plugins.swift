import LinkerSets

// Plug-ins that register themselves and are never named: no code anywhere refers to these types,
// so only their records keep them in a program. The kind is "plug".

/// A plug-in that exports reports.
@LinkerSetEntry(kind: 0x706C_7567)
struct ExportPlugin {}

/// A plug-in that imports data.
@LinkerSetEntry(kind: 0x706C_7567)
final class ImportPlugin {}
