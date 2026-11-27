// Two declarations of one kind and key in one module: the compiler refuses the second definition
// of the symbol that stands for the key, before anything links.
import LinkerSets

@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/home")
let home = 1

@LinkerSetEntry(kind: 0x726F_7574, uniqueKey: "/home")
let homeAgain = 2
