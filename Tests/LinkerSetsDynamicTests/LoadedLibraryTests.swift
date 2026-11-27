// Records in a shared library the test program doesn't link and opens itself with dlopen
// (ExampleLoadedPlugins, LOADED_SHARED_LIBRARIES in scripts/modules.py): absent until it is
// loaded, found once it is. The library stays open, since closing it would unmap the records'
// accessors. Self-contained, apart from the lookup of the library's file below.

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

@Suite("Shared libraries opened with dlopen")
struct LoadedLibraryTests {
    @Test("Records in a shared library opened with dlopen are found once it is loaded, and not before")
    func loadedLibraryRecords() throws {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6479_6E32))
        let expectedBefore: [Int] = []
        let expected = [10, 20]
        let path = try #require(loadedLibraryPath())
        let before = sut.values.sorted()

        let handle = dlopen(path, RTLD_NOW)
        let error = handle == nil ? dlerror().map { String(cString: $0) } : nil

        #expect(before == expectedBefore)
        try #require(handle != nil, "dlopen(\(path)) failed: \(error ?? "no error given")")
        let actual = sut.values.sorted()
        #expect(actual == expected)
    }
}

/// Where the build put libExampleLoadedPlugins: under Bazel, in the test's runfiles (the swift_test's
/// `data`); under SwiftPM, beside the test bundle (macOS) or binary (Linux), where it builds every
/// product. Fixture plumbing, not an assertion.
fileprivate func loadedLibraryPath() -> String? {
    #if objectFormat(MachO)
    let file = "libExampleLoadedPlugins.dylib"
    #else
    let file = "libExampleLoadedPlugins.so"
    #endif
    if let runfiles = getenv("RUNFILES_DIR") ?? getenv("TEST_SRCDIR") {
        let workspace = getenv("TEST_WORKSPACE").map { String(cString: $0) } ?? "_main"
        return "\(String(cString: runfiles))/\(workspace)/Sources/ExampleLoadedPlugins/\(file)"
    }
    #if objectFormat(MachO)
    // The image holding this code is the test bundle's binary, X.xctest/Contents/MacOS/X, which a
    // runner loads.
    var image = Dl_info()
    guard dladdr(#dsohandle, &image) != 0, let name = image.dli_fname else { return nil }
    let binary = String(cString: name)
    #else
    // The test binary is the program itself.
    var name = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
    let count = readlink("/proc/self/exe", &name, name.count - 1)
    guard count > 0 else { return nil }
    let binary = String(decoding: name.prefix(count).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    #endif
    var directory = binary.split(separator: "/", omittingEmptySubsequences: false).dropLast()
    if let bundle = directory.lastIndex(where: { $0.hasSuffix(".xctest") }) {
        directory = directory[..<bundle]
    }
    let path = (directory + [Substring(file)]).joined(separator: "/")
    #if objectFormat(MachO)
    // xcodebuild builds a dynamic product as a framework in PackageFrameworks, beside the bundle.
    if access(path, F_OK) != 0 {
        return (directory + ["PackageFrameworks", "ExampleLoadedPlugins.framework", "ExampleLoadedPlugins"]).joined(separator: "/")
    }
    #endif
    return path
}
#endif
