// Records in a shared library the test program links at launch (ExampleDynamicPlugins,
// LINKED_SHARED_LIBRARIES in scripts/modules.py): the loader maps it as an image of its own before
// the tests run, and the program holds none of its records. Bazel alone links it, so SwiftPM leaves
// this directory out (LINKED_TESTS_DIRECTORY in scripts/modules.py). Each test is self-contained.

#if objectFormat(MachO) || objectFormat(ELF)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif
import LinkerSets
import Testing

#if objectFormat(ELF)
// glibc, bionic and musl document dladdr, but declare it (and Dl_info) only under _GNU_SOURCE,
// which Swift's Glibc module leaves out. So it is declared here with `@_extern(c)` (the Extern
// experimental feature, EXPERIMENTAL_FEATURES in scripts/modules.py), a reference the linker
// resolves rather than a lookup by name, and Dl_info as the four pointers dlfcn.h lays out.
@_extern(c, "dladdr")
private func dladdr(_ address: UnsafeRawPointer?, _ info: UnsafeMutableRawPointer?) -> Int32

private struct Dl_info {
    var dli_fname: UnsafePointer<CChar>? = nil
    var dli_fbase: UnsafeMutableRawPointer? = nil
    var dli_sname: UnsafePointer<CChar>? = nil
    var dli_saddr: UnsafeMutableRawPointer? = nil
}
#endif

@Suite("Shared libraries linked at launch")
struct LinkedLibraryTests {
    @Test("Records in a shared library the program links at launch are found")
    func linkedLibraryRecords() {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6479_6E31))
        let expected = [1, 2]

        let actual = sut.values.sorted()

        #expect(actual == expected)
    }

    // dladdr maps an address to the image that holds it, which is no lookup of a symbol by name.
    @Test("Records in a shared library linked at launch sit in the library's image, not the program's")
    func linkedLibraryImage() throws {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6479_6E31))
        #if objectFormat(MachO)
        let expectedFile = "libExampleDynamicPlugins.dylib"
        #else
        let expectedFile = "libExampleDynamicPlugins.so"
        #endif
        let expectedCount = 2
        var programImage = Dl_info()
        try #require(dladdr(#dsohandle, &programImage) != 0)

        var actual: [String] = []
        for record in sut.records {
            let accessor = try #require(record.accessor)
            var image = Dl_info()
            try #require(dladdr(unsafeBitCast(accessor, to: UnsafeRawPointer.self), &image) != 0)
            #expect(image.dli_fbase != programImage.dli_fbase)
            actual.append(String(cString: try #require(image.dli_fname)))
        }

        #expect(actual.count == expectedCount)
        #expect(actual.allSatisfy { $0.hasSuffix("/" + expectedFile) || $0 == expectedFile })
    }
}
#endif
