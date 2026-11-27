// A client's internal kind stays out of its users' scope, though LinkerSet and LinkerSetKind,
// re-exported, are in it.
import ExportingClient

let reachable = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x726F_7574)).values
let hidden = LinkerSet<Int>(kind: .probes).values
