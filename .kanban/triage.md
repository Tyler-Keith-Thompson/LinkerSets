# LinkerSets: triage charter

## What it is
A Swift library, built around macros, that lets declarations register themselves at compile time
(an attached macro emits a `@used` record that SE-0492's `@section` places in the library's own
section) and be found at run time, across every module a program links, through a generic, typed
API that enumerates every record of one kind in a deterministic order. It is for library and app
authors who would otherwise keep a hand-written central list (events, routes, dependency
registrations, migrations, debug menu items, plug-ins). It optimizes for discovery that never
breaks: only each object format's documented mechanisms, on every platform Swift supports, through
release builds, dead stripping, static and dynamic linking and `dlopen`.

## In scope
- The record format: kind, accessor, context and reserved words, laid out like Swift Testing's
  test-content records, in the library's own section.
- The library's attached macros (on types, static properties, functions) and their compile-time
  diagnostics: generic declarations, members of generic types, anything a record can't describe.
- The few-line way a client declares its own kind and its own attached macro on top of the library's.
- The typed run-time enumeration API: deterministic order, typed throws or witnesses, never a trap.
- One discovery back end per object format: Mach-O (loader image list + `getsectiondata`), ELF and
  WebAssembly (`__start_`/`__stop_` symbols), COFF (`$A`/`$M`/`$Z` grouped sections).
- Platform support and its tests: macOS, iOS, tvOS, watchOS (including arm64_32), visionOS, Mac
  Catalyst, Linux, Android, Windows, FreeBSD, WASI; and per-platform documentation of what works.
- Tests and fixtures proving survival of release builds, dead stripping, static linking, dynamic
  linking and code loaded later with `dlopen`.
- DocC guides for clients (declaring a kind, migrating a hand-written registry).
- Friction reports from clients (Traffluent, DependencyInjection) about the API or macros.

## Not in scope
- N1. Scanning Swift runtime metadata (protocol conformance records, type metadata records).
  Brittle and not a documented mechanism. Rejected in every form, including as a fallback.
- N2. Build plugins or scripts that scan source text to generate a registry. The registry must come
  from compile-time records.
- N3. `dlsym` or any lookup of records by symbol name. Discovery goes through sections only.
- N4. Apple private API or undocumented loader internals.
- N5. Run-time registration APIs that must be called at launch (`register(_:)`, a mutable global
  registry). Out of scope by the owner's words: only compile-time records.
- N6. Reflection (`Mirror`, metadata walking, `_typeByName`) of any kind.
- N7. Faking a platform. A platform where linker sets can't be made reliable is documented as
  unsupported, never served by a different, weaker mechanism behind the same API.
- N8. Any dependency on Swift Testing or its underscored discovery module (`_TestDiscovery`), in
  the shipped library. Sharing the layout is the point; sharing the code is not.
- N9. Client-domain features: event schemas, routing, DI containers, migration runners, debug menus.
  Those live in the client; LinkerSets only stores and finds their records.
- N10. Run-time traps in the public API. Failures are typed throws or witnesses.
- N11. Embedded Swift, unless the same section mechanism works there unchanged.

## Rules a request must fit
- Discovery uses the format's documented mechanism only (see In scope); a request whose fix needs
  another mechanism is N1–N4 or N7.
- Every platform claim has a test that runs on that platform, or the docs say it is untested.
- Every linking scenario the library claims (release, dead stripping, static, dynamic, `dlopen`)
  has a test that would fail if the records were stripped or missed.
- Enumeration order is deterministic and documented; a change to it is a breaking change.
- Misuse that a macro can see is a compile-time diagnostic with a must-not-compile fixture, not a
  run-time error.
- The record layout is ABI: changing it needs an owner decision, not a triage accept.
- A client's kind must not see another kind's records.
- House rules in AGENTS.md apply (typed payload-free errors, value types, Swift Testing, no
  test-only hooks or SPI).

## Belongs elsewhere
- Traffluent's `@Event` macro, schemas and its migration off TRAF-112's hand-rolled discovery →
  Traffluent (this project only supplies what it needs, filed as features here).
- DependencyInjection's registration macros and container → DependencyInjection.
- Template machinery (Bazel/SwiftPM generator, CI, `just` recipes) → ProjectTemplate, unless the
  fix is local to this project's tables.
- Swift compiler or linker bugs → record locally here as a bug with the workaround; never file
  upstream (house rule).

## Kinds, labels and Ready
- feature: new capability inside In scope. bug: something claimed doesn't work (a record missed,
  order nondeterministic, a trap). friction: an API or macro that took a client too many tries.
  docs: DocC, README or AGENTS.md.
- Ready needs: what to build, the platforms and linking modes it touches, and acceptance criteria a
  test or command can show (on which platform).
- A platform item names how it is tested (CI job, simulator, emulator, cross-compile only).

## Decisions
- D1. "Fall back to conformance scanning where sections fail" → reject, N1 and N7.
- D2. "Add a `register()` call for dynamic cases" → reject, N5; code loaded later is covered by
  section discovery over `dlopen`ed images.
- D3. "Use Swift Testing's `_TestDiscovery` / its section" → reject, N8; same layout, own section.
- D4. Requests for a new client-specific record kind built into the library → reject; clients
  declare their own kind on top of the library's (In scope), and the library ships only the
  mechanism.

## Open questions
- Q1. Minimum deployment targets: the template defaults are macOS 15, iOS 18, tvOS 18, watchOS 11,
  visionOS 2. Do they stay, or go lower for Traffluent's adopters?
- Q2. Which platforms get real CI runs (Android emulator, Windows, FreeBSD, watchOS arm64_32
  device or simulator) versus cross-compile-only, and is cross-compile-only enough to claim support?
- Q3. Do records from a `dlopen`ed image that is later `dlclose`d disappear from enumeration, and
  must the API notice image loads after first enumeration (observe the loader) or only on each call?
- Q4. Kind identity: a 32-bit value as in Swift Testing (FourCC-style), a larger one, or derived
  by the macro from a client's type name; and who prevents two clients picking the same kind?
- Q5. What "deterministic order" means across modules: link order, image order then section order,
  or sorted by a key the record carries?
- Q6. Should the record layout be kept byte-compatible with Swift Testing's across future Swift
  Testing changes, or frozen at today's layout?
- Q7. Is Embedded Swift a goal to investigate (does `@section` with `@used` work there), or out until
  someone asks?
- Q8. Versioning and the first release: what must be supported before 0.1.0 (Apple + Linux only?)
  so Traffluent can adopt it?
