# Platforms and linking

Where records are found, how, and which test shows it.

## Overview

Each object format places records in a section of its own and has its own documented way to find
them at run time. None reads Swift's runtime metadata or looks a symbol up by name.

| Platform | Section | How records are found |
|---|---|---|
| macOS, iOS, tvOS, watchOS, visionOS, Mac Catalyst | `__DATA_CONST,__linker_sets` | The loader's image list (`_dyld_image_count`, `_dyld_get_image_header`) and `getsectiondata` in each image |
| Linux, Android | `.note.linker_sets`, each record an ELF note | `dl_iterate_phdr` and each image's `PT_NOTE` segments |
| WebAssembly (WASI) | `linker_sets` | Between the `__start_linker_sets` and `__stop_linker_sets` symbols wasm-ld defines |
| Windows | `.lnkset$M`, merged by the linker into `.lnkset` | `K32EnumProcessModules` and each module's PE section table, skipping the zero padding the linker may put between contributions |

### What is tested where

| Platform and linking mode | Covered by | Runs in |
|---|---|---|
| macOS, modules linked statically, debug | `LinkerSetsTests`: `LinkerSetEnumerationTests`, `ClientKindsTests`, `UnknownVersionEnumerationTests`, `READMEExamplesTests` | `just test`, `just spm-test` |
| macOS, release with dead stripping, an unreferenced module's records kept | `LinkerSetsPerformanceTests`: `LinkingTests` | `just test-release` |
| macOS, a shared library linked at launch | `LinkerSetsDynamicTests`: `LinkedLibraryTests` | `just test` (Bazel only) |
| macOS, a library loaded with `dlopen` after the first read | `LinkerSetsDynamicTests`: `LoadedLibraryTests` | `just test`, `just spm-test` |
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

A record is in the program only if its object file is. SwiftPM and Bazel link every module a target
depends on. A build that pulls a static archive's members in only on demand leaves out a module
nothing calls into: link it whole with `-force_load` (Apple platforms) or `--whole-archive`
(Linux).
