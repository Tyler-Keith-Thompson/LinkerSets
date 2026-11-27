/// The tag that says which client a linker-set record belongs to.
///
/// Every record in the section LinkerSets owns starts with a kind, and enumeration returns only
/// the records of the kind asked for, so many clients share one section without seeing each
/// other's records. A kind is a 32-bit value, conventionally four ASCII characters read as a
/// big-endian integer, as Swift Testing's test-content kinds are (`0x74657374` is `"test"`).
///
/// ```swift
/// extension LinkerSetKind {
///     /// Records of routes, `"rout"`.
///     static let routes = LinkerSetKind(rawValue: 0x726F_7574)
/// }
/// ```
///
/// A client picks one kind for its records and keeps it: records already compiled into other
/// modules carry the value they were built with. Kind 0 is reserved: it marks a slot that holds
/// no record, and a ``LinkerSet`` of it is always empty.
@frozen
public struct LinkerSetKind: RawRepresentable, Hashable, Sendable {
    /// The value written into each record of this kind.
    public var rawValue: UInt32

    /// A kind whose records hold `rawValue`.
    ///
    /// - Parameter rawValue: The value each record of this kind holds in its first word.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension LinkerSetKind {
    /// Kind 0: zero padding between records, and the placeholder that keeps the section present
    /// in every image.
    static let emptySlot = LinkerSetKind(rawValue: 0)
}
