// The control for the @LinkerSetEntry fixtures: every declaration a record describes compiles.
import LinkerSets

@MainActor
enum Screens {
    @LinkerSetEntry(kind: 0x6366_0100)
    static func show() {}

    @LinkerSetEntry(kind: 0x6366_0100)
    nonisolated static func describe() -> String { "" }

    @LinkerSetEntry(kind: 0x6366_0100)
    static let title = "Screens"
}

enum Menu {
    @MainActor @LinkerSetEntry(kind: 0x6366_0100)
    static func open() {}
}

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

// Unique keys, at file scope, in a main-actor type, in a struct and in an extension.
@LinkerSetEntry(kind: 0x6366_0101, uniqueKey: "home")
let keyedHome = 1

@MainActor
enum KeyedScreens {
    @LinkerSetEntry(kind: 0x6366_0101, uniqueKey: "screens.show")
    static func show() {}
}

struct KeyedWorker {
    @LinkerSetEntry(kind: 0x6366_0101, uniqueKey: "worker.start")
    static func start() {}
}

extension Settings {
    @LinkerSetEntry(kind: 0x6366_0101, uniqueKey: "settings.contrast")
    static let contrast = 3
}

// Static members of an actor, a class, a type nested in a class and a class's extension, whose
// records name the type rather than the covariant `Self`.
actor Dispatcher {
    @LinkerSetEntry(kind: 0x6366_0101, uniqueKey: "dispatcher.start")
    static func start() {}

    @LinkerSetEntry(kind: 0x6366_0100)
    static let name = "worker"
}

class Scheduler {
    @LinkerSetEntry(kind: 0x6366_0100)
    static func start() {}

    @LinkerSetEntry(kind: 0x6366_0100)
    static let interval = 5

    enum Jobs {
        @LinkerSetEntry(kind: 0x6366_0100)
        static func clean() {}
    }
}

extension Scheduler {
    @LinkerSetEntry(kind: 0x6366_0100)
    static func stop() {}
}
