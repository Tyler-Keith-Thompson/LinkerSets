extension LinkerSetRecord {
    /// Why a record produced no value of the type asked for.
    public enum ValueError: Error, Hashable, Sendable {
        /// The slot holds no record: its accessor is null, as in the zero padding a linker may
        /// leave between records.
        case emptySlot
        /// The record's accessor declined the type: its value is of another type.
        case typeMismatch
        /// The record's reserved fields aren't zero, so a newer layout wrote it, whose accessor
        /// this version of LinkerSets can't call safely.
        case unsupportedVersion
    }
}
