// The run-time half, LinkerSet and the types it reads, lives in LinkerSetsRuntime, which builds no
// macros: a module that only reads records depends on it alone. This module adds @LinkerSetEntry
// and re-exports it, so `import LinkerSets` gives both.
@_exported import LinkerSetsRuntime
