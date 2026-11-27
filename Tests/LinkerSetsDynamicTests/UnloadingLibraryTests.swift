// Reading records while another thread opens and closes a shared library again and again. On
// Apple platforms the library is ExampleUnloadedPlugins (LOADED_SHARED_LIBRARIES in
// scripts/modules.py), which dyld keeps mapped after dlclose since it holds Swift code. On Linux it
// is glibc's libanl, which holds no Swift code and which the loader does unmap: closing a Swift
// library there leaves its metadata registered with the Swift runtime, and the next dynamic cast
// crashes, whatever reads it. Android's bionic has no such library at hand, so it runs the
// dlopen tests in LoadedLibraryTests alone. Self-contained, apart from the lookup of the library's
// file below.

#if canImport(Darwin) || os(Linux)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import LinkerSets
import Synchronization
import Testing

/// Records of this test program's own, kind "dyn4", which every read must find while the library
/// comes and goes.
enum UnloadingFixtures {
    @LinkerSetEntry(kind: 0x6479_6E34)
    static let first = 1

    @LinkerSetEntry(kind: 0x6479_6E34)
    static let second = 2
}

@Suite("Shared libraries closed with dlclose", .timeLimit(.minutes(1)))
struct UnloadingLibraryTests {
    @Test("Reads while another thread opens and closes a library keep finding the program's own records")
    func readsWhileLoadingAndUnloading() async throws {
        let sut = LinkerSet<Int>(kind: LinkerSetKind(rawValue: 0x6479_6E34))
        let expectedCounts: Set<Int> = [2]
        let path = try #require(unloadedLibraryPath())
        let rounds = 100
        let finished = Atomic(false)
        let loader = Task.detached {
            defer { finished.store(true, ordering: .releasing) }
            for _ in 0..<rounds {
                guard let handle = dlopen(path, RTLD_NOW) else { return false }
                dlclose(handle)
            }
            return true
        }
        var actualCounts: Set<Int> = []

        repeat {
            actualCounts.insert(sut.records.count)
            // A read holds the loader's lock on Linux, which isn't fair: without a yield, back-to-back
            // reads can keep dlopen waiting for minutes.
            sched_yield()
        } while !finished.load(ordering: .acquiring)

        let opened = await loader.value
        #expect(opened, "dlopen(\(path)) failed")
        #expect(actualCounts == expectedCounts)
    }
}

/// The library the test opens and closes: glibc's libanl on Linux, found by the loader's search;
/// on Apple platforms libExampleUnloadedPlugins, under Bazel in the test's runfiles (the
/// swift_test's `data`), under SwiftPM beside the test bundle. Fixture plumbing, not an assertion.
fileprivate func unloadedLibraryPath() -> String? {
    #if os(Linux)
    return "libanl.so.1"
    #else
    let file = "libExampleUnloadedPlugins.dylib"
    if let runfiles = getenv("RUNFILES_DIR") ?? getenv("TEST_SRCDIR") {
        let workspace = getenv("TEST_WORKSPACE").map { String(cString: $0) } ?? "_main"
        return "\(String(cString: runfiles))/\(workspace)/Sources/ExampleUnloadedPlugins/\(file)"
    }
    // The image holding this code is the test bundle's binary, X.xctest/Contents/MacOS/X, which a
    // runner loads.
    var image = Dl_info()
    guard dladdr(#dsohandle, &image) != 0, let name = image.dli_fname else { return nil }
    var directory = String(cString: name).split(separator: "/", omittingEmptySubsequences: false).dropLast()
    if let bundle = directory.lastIndex(where: { $0.hasSuffix(".xctest") }) {
        directory = directory[..<bundle]
    }
    let path = (directory + [Substring(file)]).joined(separator: "/")
    // xcodebuild builds a dynamic product as a framework in PackageFrameworks, beside the bundle.
    if access(path, F_OK) != 0 {
        return (directory + ["PackageFrameworks", "ExampleUnloadedPlugins.framework", "ExampleUnloadedPlugins"]).joined(separator: "/")
    }
    return path
    #endif
}
#endif
