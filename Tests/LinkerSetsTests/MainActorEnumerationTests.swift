// Declarations isolated to the main actor, registered and read back: functions as their
// @MainActor function type, called on the main actor, and a let of a @MainActor type as its value.
// Kinds "lsm1" through "lsm3" belong to this file alone.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm)
import LinkerSets
import Testing

@MainActor
enum MainActorScreens {
    static var shown: [String] = []

    @LinkerSetEntry(kind: 0x6C73_6D31)
    static func showHome() { shown.append("home") }
}

enum MainActorMenu {
    @MainActor @LinkerSetEntry(kind: 0x6C73_6D32)
    static func title() -> String { "Menu" }
}

@MainActor
enum MainActorTitles {
    @LinkerSetEntry(kind: 0x6C73_6D33)
    static let home = "Home"
}

@Suite("LinkerSet: main-actor isolated declarations")
@MainActor
struct MainActorEnumerationTests {
    @Test("A static function of a @MainActor type is found as a @MainActor function and runs there")
    func functionOfMainActorType() {
        let expected = ["home"]

        let actions = LinkerSet<@MainActor () -> Void>(kind: LinkerSetKind(rawValue: 0x6C73_6D31)).values
        for action in actions { action() }

        #expect(MainActorScreens.shown == expected)
    }

    @Test("A @MainActor static function is found as its @MainActor function type")
    func mainActorFunction() {
        let expected = ["Menu"]

        let actual = LinkerSet<@MainActor () -> String>(kind: LinkerSetKind(rawValue: 0x6C73_6D32)).values.map { $0() }

        #expect(actual == expected)
    }

    @Test("A @MainActor function isn't found as its nonisolated function type")
    func notNonisolated() {
        let actual = LinkerSet<() -> String>(kind: LinkerSetKind(rawValue: 0x6C73_6D32)).values

        #expect(actual.isEmpty)
    }

    @Test("A static let of a @MainActor type is found as its value")
    func letOfMainActorType() {
        let expected = ["Home"]

        let actual = LinkerSet<String>(kind: LinkerSetKind(rawValue: 0x6C73_6D33)).values

        #expect(actual == expected)
    }
}
#endif
