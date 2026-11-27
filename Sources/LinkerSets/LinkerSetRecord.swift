/// One entry in a linker set: a record an attached macro places in the section LinkerSets owns.
///
/// The layout is Swift Testing's test-content record, field for field, so tools that read one
/// can read the other:
///
/// | Field | Type | 64-bit offset | 32-bit offset |
/// |---|---|---|---|
/// | `kind` | `UInt32` | 0 | 0 |
/// | reserved | `UInt32` | 4 | 4 |
/// | `accessor` | C function pointer | 8 | 8 |
/// | `context` | `UInt` | 16 | 12 |
/// | reserved | `UInt` | 24 | 16 |
///
/// A record is 32 bytes with 8-byte alignment where pointers are 64 bits, and 20 bytes with
/// 4-byte alignment where they are 32 bits (watchOS's arm64_32, wasm32). Records sit back to back
/// in the section, one ``LinkerSetRecord/Literal`` per declaration, and are read in place as
/// `LinkerSetRecord` values; the two types have the same layout.
@frozen
public struct LinkerSetRecord {
    /// The function that produces a record's value.
    ///
    /// `type` points to the metatype of the value asked for (read it with
    /// `type.load(as: Any.Type.self)`), and `outValue` to uninitialized memory of that type. The
    /// accessor writes the value there and returns `true`, or returns `false` and writes nothing
    /// when it has no value of that type or when `hint` (a kind-specific filter, or `nil`) rules
    /// it out. `reserved` is zero.
    public typealias Accessor = @convention(c) (
        _ outValue: UnsafeMutableRawPointer,
        _ type: UnsafeRawPointer,
        _ hint: UnsafeRawPointer?,
        _ reserved: UInt
    ) -> Bool

    /// A record as a macro writes it: a tuple of the record's fields, in order.
    ///
    /// A global placed with `@section` must be initialized by a constant expression, which allows
    /// tuples of literals and function references but neither a struct's initializer nor an
    /// optional, so the macros emit this tuple, with a non-optional accessor and zero reserved
    /// fields:
    ///
    /// ```swift
    /// let record: LinkerSetRecord.Literal = (0x726F_7574, 0, { outValue, type, hint, reserved in false }, 0, 0)
    /// ```
    // A tuple rather than a struct because SE-0492's constant expressions take no initializer
    // calls; `LinkerSetRecord` is the struct the run-time API reads the same bytes as.
    public typealias Literal = (
        kind: UInt32,
        reserved1: UInt32,
        accessor: Accessor,
        context: UInt,
        reserved2: UInt
    )

    /// A record as a macro writes it in an ELF image: the record, wrapped in an ELF note.
    ///
    /// In an ELF image the records sit in the note section `.note.linker_sets`, which the linker
    /// covers with a `PT_NOTE` program header, so ``LinkerSet`` finds each loaded image's records
    /// through `dl_iterate_phdr`, a shared library's and a `dlopen`ed one's included. Each note
    /// has the standard header: `nameSize` 11 and `name` `"LinkerSets"` with its terminating
    /// zero, padded to 12 bytes; `descriptorSize`, the size of a record (32 bytes where pointers
    /// are 64 bits, 20 where they are 32); and `type` 1. The record follows as the descriptor:
    ///
    /// ```swift
    /// let note: LinkerSetRecord.Note = (11, 32, 1, (76, 105, 110, 107, 101, 114, 83, 101, 116, 115, 0, 0),
    ///                                   (0x726F_7574, 0, { outValue, type, hint, reserved in false }, 0, 0))
    /// ```
    ///
    /// The 24-byte header keeps the record at its own alignment, whether a reader aligns notes to
    /// 4 bytes or to 8.
    // A note rather than a plain section bounded by __start_/__stop_ symbols: those bound only the
    // image whose code takes their address, so a shared library's records would need code of the
    // library's own to report them. A note segment is visible in every loaded image's program
    // headers.
    public typealias Note = (
        nameSize: UInt32,
        descriptorSize: UInt32,
        type: UInt32,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        record: Literal
    )

    /// The client this record belongs to.
    public let kind: LinkerSetKind
    @usableFromInline let reserved1: UInt32
    /// The function that produces this record's value, or `nil` for a slot holding no record
    /// (the zero padding a linker may leave between records).
    public let accessor: Accessor?
    /// A word the record's kind gives meaning to, such as flags or a hash of its name; zero when
    /// the kind uses none.
    public let context: UInt
    @usableFromInline let reserved2: UInt

    /// Whether this version of LinkerSets can read the record: its reserved fields are zero, as
    /// every record of the current layout's are.
    public var isSupportedVersion: Bool {
        reserved1 == 0 && reserved2 == 0
    }

    /// The value this record produces as a `Value`.
    ///
    /// - Parameter type: The type to ask the record's accessor for.
    /// - Returns: The value the accessor wrote.
    /// - Throws: ``ValueError/emptySlot`` when the slot holds no record,
    ///   ``ValueError/unsupportedVersion`` when its reserved fields aren't zero, and
    ///   ``ValueError/typeMismatch`` when its accessor declines `Value`.
    public func value<Value>(as type: Value.Type = Value.self) throws(ValueError) -> Value {
        guard let accessor else { throw .emptySlot }
        guard isSupportedVersion else { throw .unsupportedVersion }
        let value = withUnsafeTemporaryAllocation(of: Value.self, capacity: 1) { buffer -> Value? in
            // A temporary allocation of capacity 1 always has a base address; nil here would mean
            // the allocator broke its contract, which no caller could handle.
            let outValue = buffer.baseAddress!
            let produced = withUnsafePointer(to: type) { typePointer in
                accessor(UnsafeMutableRawPointer(outValue), UnsafeRawPointer(typePointer), nil, 0)
            }
            return produced ? outValue.move() : nil
        }
        guard let value else { throw .typeMismatch }
        return value
    }

    /// The body of an accessor the macros write: stores `value` into `outValue` when `type`
    /// points to `Value`'s metatype.
    ///
    /// For the macros' expansions only.
    ///
    /// - Parameters:
    ///   - value: The record's value, evaluated only when it is asked for.
    ///   - outValue: Uninitialized memory for a `Value`.
    ///   - type: A pointer to the metatype asked for.
    /// - Returns: `true` when the value was stored, `false` when `type` is another type.
    public static func __store<Value>(
        _ value: @autoclosure () -> Value,
        into outValue: UnsafeMutableRawPointer,
        ifAsked type: UnsafeRawPointer
    ) -> Bool {
        guard type.load(as: Any.Type.self) == Value.self else { return false }
        outValue.initializeMemory(as: Value.self, to: value())
        return true
    }
}
