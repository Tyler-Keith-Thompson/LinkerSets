// The control for the @LinkerSetEntry fixtures: every declaration a record describes compiles.
import LinkerSets

enum Settings {
    @LinkerSetEntry(kind: 0x6366_0100)
    static let volume = 1

    @LinkerSetEntry(kind: 0x6366_0100)
    static func reset() {}

    @LinkerSetEntry(kind: 0x6366_0100)
    struct Nested {}
}

extension Settings {
    @LinkerSetEntry(kind: 0x6366_0100)
    static var brightness: Int { 2 }
}

@LinkerSetEntry(kind: 0x6366_0100)
let home = 1

@LinkerSetEntry(kind: 0x6366_0100)
func configure() {}

@LinkerSetEntry(kind: 0x6366_0100)
final class Plugin {}

@LinkerSetEntry(kind: 0x6366_0100)
actor Worker {}
