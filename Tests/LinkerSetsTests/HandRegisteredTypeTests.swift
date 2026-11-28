// Types registered by hand as their existential metatype, the way FindingRecords shows, and read
// back as `any P.Type`. Kind "lsht" belongs to this file alone.

#if objectFormat(MachO) || objectFormat(ELF) || objectFormat(Wasm) || objectFormat(COFF)
import LinkerSets
import Testing

protocol HandRegisteredStep: SendableMetatype {
    static var name: String { get }
}

struct HandRegisteredFirst: HandRegisteredStep {
    static let name = "first"
}

struct HandRegisteredSecond: HandRegisteredStep {
    static let name = "second"
}

enum HandRegisteredSteps {
    @LinkerSetEntry(kind: 0x6C73_6874)
    static let first: any HandRegisteredStep.Type = HandRegisteredFirst.self

    @LinkerSetEntry(kind: 0x6C73_6874)
    static let second: any HandRegisteredStep.Type = HandRegisteredSecond.self
}

@MainActor
protocol HandRegisteredScreen: SendableMetatype {
    static var title: String { get }
}

@MainActor
struct HandRegisteredHome: HandRegisteredScreen {
    static let title = "Home"
}

enum HandRegisteredScreens {
    @LinkerSetEntry(kind: 0x6C73_6875)
    static let home: any HandRegisteredScreen.Type = HandRegisteredHome.self
}

@Suite("LinkerSet: types registered by hand as their existential metatype")
struct HandRegisteredTypeTests {
    @Test("A static let typed `any P.Type` is found by a LinkerSet of `any P.Type`")
    func existentialMetatype() {
        let expected = ["first", "second"]

        let actual = LinkerSet<any HandRegisteredStep.Type>(kind: LinkerSetKind(rawValue: 0x6C73_6874)).values
            .map { $0.name }
            .sorted()

        #expect(actual == expected)
    }

    @Test("A type registered as `any P.Type` isn't found as `Any.Type`")
    func notAnyType() {
        let actual = LinkerSet<Any.Type>(kind: LinkerSetKind(rawValue: 0x6C73_6874)).values

        #expect(actual.isEmpty)
    }

    @Test("A type of a @MainActor protocol refining SendableMetatype is found as `any P.Type`")
    @MainActor
    func mainActorProtocol() {
        let expected = ["Home"]

        let actual = LinkerSet<any HandRegisteredScreen.Type>(kind: LinkerSetKind(rawValue: 0x6C73_6875)).values
            .map { $0.title }

        #expect(actual == expected)
    }
}
#endif
