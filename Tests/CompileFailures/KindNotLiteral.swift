// The kind must be a literal the macro can read at compile time.
import LinkerSets

let routes: UInt32 = 0x726F_7574

@LinkerSetEntry(kind: routes)
let home = 1
