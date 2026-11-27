# Performance

What records cost as an app grows: nothing at launch, a walk of the records when a set is read,
and a few milliseconds of build time per marked declaration.

## Overview

A record is data the linker places in a section, so nothing runs for it at launch. Reading a set
walks every loaded image's section once and calls the accessor of each record of the set's kind.
That's linear in the records the program holds, and the reads aren't cached, so read a set once
where the program starts and keep the array. `LinkerSetsPerformanceTests` checks the scaling in
release builds: reading 3,000 records costs no more than about 10 times reading 300.

The build pays for each marked declaration: the macro's expansion and the record it compiles to.
That cost is also linear while the records are spread across files, as they are in an app.
Thousands of records in one file take the compiler much longer, so generated registries are
better split.

### Measured

`just benchmark` measures both in a SwiftPM package of generated records, against the same
declarations without the macro. These figures are from an M1 Ultra with Swift 6.4.2, in a debug
build, with each size's records split across 10 files:

| Records | Build time the records add | Per record | Reading every record (release) |
|---:|---:|---:|---:|
| 100 | 2.6 s | 26 ms | 77 µs |
| 1,000 | 4.2 s | 4.3 ms | 242 µs |
| 10,000 | 50 s | 5.0 ms | 2.0 ms |

The 100-record row is mostly the macro plugin's start-up, paid once per module that uses it. A
read also has a fixed part, the walk over every image the process has loaded, which is about
70 µs on macOS. In a single file, 10,000 records added 111 s to the build instead of 50 s.
