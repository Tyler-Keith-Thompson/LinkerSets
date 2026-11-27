@_exported import LinkerSetsRuntime

// A client's declarations, on LinkerSetsRuntime alone: the entry macro its users write, and the
// record macro its expansion calls. The re-export puts LinkerSetsRuntime, which the expansion
// names, in its users' scope.

/// Registers a static property, a static function, a global or a type as a record of `kind`,
/// read with `LinkerSet(kind:)`.
@attached(peer)
public macro Discoverable(kind: UInt32) = #externalMacro(module: "ExampleDiscoveryMacros", type: "DiscoverableMacro")

/// The record `@Discoverable` writes: one record of `kind` whose accessor stores `value`.
@freestanding(declaration)
public macro discoverableRecord<Value>(kind: UInt32, storing value: Value) = #externalMacro(module: "ExampleDiscoveryMacros", type: "DiscoverableRecordMacro")
