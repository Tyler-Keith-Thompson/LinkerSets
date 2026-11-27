// A unique key the macro can't read at compile time: a name, not a string literal.
import LinkerSets

let path = "/home"

@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: path)
let home = 1
