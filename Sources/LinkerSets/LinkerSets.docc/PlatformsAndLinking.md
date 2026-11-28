# Platforms and linking

Where records are found, how, and which test shows it.

## Overview

Each object format places records in a section of its own and has its own documented way to find
them at run time. None reads Swift's runtime metadata or looks a symbol up by name.

| Platform | Section | How records are found |
|---|---|---|
| macOS, iOS, tvOS, watchOS, visionOS, Mac Catalyst | `__DATA_CONST,__linker_sets` | The loader's image callbacks (`_dyld_register_func_for_add_image`, `_dyld_register_func_for_remove_image`) and `getsectiondata` in each image |
| Linux, Android | `.note.linker_sets`, each record an ELF note | `dl_iterate_phdr` and each image's `PT_NOTE` segments |
| WebAssembly (WASI) | `linker_sets` | Between the `__start_linker_sets` and `__stop_linker_sets` symbols wasm-ld defines |
| Windows | `.lnkset$M`, merged by the linker into `.lnkset` | `K32EnumProcessModules`, each module pinned with `GetModuleHandleExW` while its PE section table is read, skipping the zero padding the linker may put between contributions |

### What is tested where

| Platform and linking mode | Covered by | Runs in |
|---|---|---|
| macOS, modules linked statically, debug | `LinkerSetsTests`: `LinkerSetEnumerationTests`, `ClientKindsTests`, `UnknownVersionEnumerationTests`, `READMEExamplesTests` | `just test`, `just spm-test` |
| macOS, release with dead stripping, an unreferenced module's records kept | `LinkerSetsPerformanceTests`: `LinkingTests` | `just test-release` |
| macOS, a shared library linked at launch | `LinkerSetsDynamicTests`: `LinkedLibraryTests` | `just test` (Bazel only) |
| macOS, a library loaded with `dlopen` after the first read | `LinkerSetsDynamicTests`: `LoadedLibraryTests` | `just test`, `just spm-test` |
| macOS and Linux, a library opened and closed in a loop while another thread reads (on Linux, glibc's `libanl`, which the loader unmaps) | `LinkerSetsDynamicTests`: `UnloadingLibraryTests` | `just test`, `just spm-test`, CI's Linux jobs |
| iOS simulator, inside an app's bundle | `LinkerSetsTestsSimulator` | `just test` on a Mac |
| tvOS, watchOS and visionOS simulators, Mac Catalyst | `LinkerSetsTests`, `LinkerSetsPerformanceTests`, `LinkerSetsDynamicTests` (`dlopen`) | `just apple-test` |
| watchOS devices, 32-bit arm64_32, compiled | `LinkerSetRecordLayoutTests` (the 20-byte record) | `just apple-test` |
| Linux, static, shared and `dlopen`ed libraries, debug and release | The same targets as macOS, and `LinkerSetNoteTests` (the note walk) | CI's Linux Bazel and SwiftPM jobs |
| WebAssembly, a 32-bit `Int`, debug and release | `LinkerSetsTests`, `LinkerSetsPerformanceTests` | `just wasi-test`, `just wasi-test -c release` |
| Windows, modules linked statically | `LinkerSetsTests`, `LinkerSetsPerformanceTests`, and `LinkerSetPaddedSectionTests` (the padding walk, on every platform) | CI's Windows workflow, when Windows code changes |
| Android (aarch64, an Android 15 emulator), modules linked statically and a library loaded with `dlopen`, debug and release | `LinkerSetsTests` (`LinkerSetNoteTests` among them), `LinkerSetsPerformanceTests`, `LinkerSetsDynamicTests` (`dlopen`) | `just android-test`, `just android-test -c release`, on a Mac; not in CI |
| Android, a shared library linked at launch | Untested: the test of it builds under Bazel only; `dl_iterate_phdr` reads it as it does a `dlopen`ed library | |

A WebAssembly program is one statically linked module, so it has no shared libraries to search.

### Linking modes

Records survive dead stripping (`-dead_strip`, `--gc-sections`) in debug and release builds: each
record is marked `@used`, and the section is kept. Shared libraries carry their own records,
found once the loader has mapped them, whether linked at launch or opened later with `dlopen`.

A record is in the program only if its object file is. The linker decides this per object file,
not per module. It takes a member of a static archive only when something already linked
references a symbol in it. So a file of a module that the program does call into can still be
left out, with its records, when nothing references that file. Dead stripping is a separate step:
it never removes a record from an object file that was linked.

SwiftPM links every object file of each module a target depends on. Bazel does the same only for
targets with `alwayslink = True`. That is `swift_library`'s default in rules_swift, but
`cc_library` and `objc_library` default to `False`, so their object files are linked only on
demand. To link an archive whole, pass `-force_load` (Apple platforms) or `--whole-archive`
(Linux, Android), or set `alwayslink` on the Bazel target.

With `-ObjC`, Apple's linker loads the archive members that hold Objective-C classes or
categories, Swift type metadata (`__swift5_types`) or protocol conformances (`__swift5_proto`).
It still leaves out a member that holds only records, such as one whose records are on functions
or globals, inside a private enum, or in an extension that adds static members but no
conformance. Those members need `-force_load`. These are the linker's
rules, seen with Xcode's `ld` and Swift 6.4.2; LinkerSets has no test of them.

### Loading and unloading during a read

A read takes a snapshot: every image loaded when the walk reaches it is read whole, and an image
loaded or unloaded while a read runs is either in that read's records in full or absent.

| Format | An image loaded during a read | An image unloaded during a read |
|---|---|---|
| Mach-O | Found if dyld added it before the walk took its lock, missed otherwise | dyld calls the remove callback before it unmaps an image, and the callback waits for the walk's lock, so the image is read whole or not at all. dyld never unmaps an image that holds Swift code |
| ELF | `dl_iterate_phdr` holds the loader's lock for the whole walk, so a `dlopen` finishing during it waits, and is missed | A `dlclose` waits for the walk the same way |
| COFF | Found if `K32EnumProcessModules` listed it, missed otherwise | Each module is pinned with `GetModuleHandleExW` while its headers are read; one freed before that is left out |
| WebAssembly | A program is one module; nothing loads or unloads | |

The next read sees the change: a library opened since is found, and one the loader has unmapped
since is gone.

### Records of a closed library

A record's accessor and the value it hands back live in the record's image, and so does the Swift
metadata of the record's type. On Apple platforms dyld never unmaps an image that holds Swift code,
so a library with records stays mapped after `dlclose`: its records are still found, and they and
their values stay valid.

On Linux and Android the loader unmaps a library once its last handle is closed, but the Swift
runtime keeps the library's type metadata and conformances registered. After that, the process can
crash in any later dynamic cast or `print`, whether or not LinkerSets reads anything. A
``/LinkerSetsRuntime/LinkerSetRecord`` copied out of the library also holds a dangling accessor,
which ``/LinkerSetsRuntime/LinkerSetRecord/value(as:)`` would call. LinkerSets can't detect either
case, because nothing tells a copied record that its image is gone.

Don't `dlclose` a library that holds Swift code, records included, while the process runs. Open
plug-ins once and keep them open; a library opened with `RTLD_NODELETE` stays mapped after
`dlclose`. Closing a
library without Swift code (a C library) is safe while another thread reads: the walk never touches
an image that is going away.

