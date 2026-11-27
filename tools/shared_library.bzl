"""A Swift module built as a shared library too (SHARED_LIBRARIES in scripts/modules.py).

`swift_shared_library` links a `swift_library`, with everything it depends on, into one shared
library named as SwiftPM names a `.library(type: .dynamic)` product: `lib<Module>.dylib` on macOS,
`lib<Module>.so` on Linux. Other platforms have no such target, so `bazel build //...` skips it
there.

It declares two targets in the module's package:

  * `:SharedLibrary`, the library file, for a test's `data`: a test that opens it with `dlopen`
    finds it in its runfiles (LOADED_SHARED_LIBRARIES).
  * `:LinkedSharedLibrary`, a `cc_import` of that file, for a test's `deps`: the test links it, so
    the loader maps it as an image of its own at launch (LINKED_SHARED_LIBRARIES). Bazel puts it in
    the test's runfiles and the test's run path.

Rejected: rules_apple's `macos_dylib`, which covers macOS alone; `cc_shared_library`, whose
`dynamic_deps` a `swift_test` doesn't take.
"""

load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_import")

# The library's load name is its file name on the run path, as SwiftPM's is, rather than the path
# Bazel linked it at, which the test's sandbox doesn't have. It is dead-stripped as tests are
# (tools/swift_rules.bzl), so the records it holds must survive that too.
_PLATFORMS = {
    "macos": ("dylib", lambda file: ["-Wl,-install_name,@rpath/" + file, "-Wl,-dead_strip"]),
    "linux": ("so", lambda file: ["-Wl,-soname," + file, "-Wl,--gc-sections"]),
}

def swift_shared_library(module_name, library, tags = [], visibility = None):
    """Links `library`, the swift_library of module `module_name`, as a shared library.

    Args:
        module_name: The module's name, which the file's name carries (`lib<module_name>.dylib`).
        library: The module's swift_library.
        tags: Tags for every target declared.
        visibility: Visibility of `:SharedLibrary` and `:LinkedSharedLibrary`.
    """
    files = {}
    for os_name, (extension, linkopts) in _PLATFORMS.items():
        file = "lib{}.{}".format(module_name, extension)
        files["@platforms//os:" + os_name] = ":" + file
        cc_binary(
            name = file,
            linkshared = True,
            linkopts = linkopts(file),
            deps = [library],
            tags = tags,
            target_compatible_with = ["@platforms//os:" + os_name],
        )
    native.alias(
        name = "SharedLibrary",
        # Elsewhere, an incompatible target, so whatever depends on it is skipped too.
        actual = select(files | {"//conditions:default": files["@platforms//os:linux"]}),
        tags = tags,
        visibility = visibility,
    )
    cc_import(
        name = "LinkedSharedLibrary",
        shared_library = ":SharedLibrary",
        tags = tags,
        visibility = visibility,
    )
