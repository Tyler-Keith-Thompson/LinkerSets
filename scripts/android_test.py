#!/usr/bin/env python3
"""Builds the SwiftPM test targets for Android and runs them on a running emulator or device.

`just test` doesn't reach Android. This builds every test target with swift.org's Swift SDK for
Android (`swift build --build-tests --swift-sdk swift-<version>-RELEASE_android --triple
aarch64-unknown-linux-android23`, through swiftly's toolchain of the same version, into
`.build/android`), pushes each `<Target>-test-runner` with the package's shared libraries, the
Swift runtime from the SDK and the NDK's libc++_shared.so to `/data/local/tmp/linkersets`, and runs
it with `--testing-library swift-testing` (without it the runner runs XCTest, which has no tests
here). Swift Testing ships only in the SDK's dynamic resources, so the runners link the Swift
runtime dynamically rather than with `--static-swift-stdlib`.

Usage: `just android-test [-c release]`. A release build adds `-enable-testing`, so suites that
`@testable import` build. Needs swiftly's toolchain of the SDK's version, the SDK (`swift sdk
list`), the Android NDK (`ANDROID_NDK_HOME`, default `~/Library/Android/ndk/android-ndk-r30`) and
one booted aarch64 emulator or device on `adb` (`ANDROID_HOME`, default `~/Library/Android/sdk`).
Logs go to `.build/android/logs`. A target fails when its runner exits non-zero or prints no
Swift Testing run; the build fails on a warning from a source in this repository.
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRATCH = ROOT / ".build" / "android"
LOGS = SCRATCH / "logs"
SWIFT_VERSION = "6.4.3"
SDK_NAME = f"swift-{SWIFT_VERSION}-RELEASE_android"
TRIPLE = "aarch64-unknown-linux-android23"
DEVICE_DIRECTORY = "/data/local/tmp/linkersets"
FIRST_PARTY_WARNING = re.compile(r"/(Sources|Tests)/[^:\s]*\.swift:\d+:\d+: (\x1b\[[0-9;]*m)*warning:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def environment_path(name, default):
    return pathlib.Path(os.environ.get(name, str(pathlib.Path.home() / default)))


def build(configuration, ndk):
    """Builds the test targets; returns the products directory, or None when the build failed."""
    LOGS.mkdir(parents=True, exist_ok=True)
    log = LOGS / f"build-{configuration}.log"
    command = ["swiftly", "run", "swift", "build", "--build-tests", "-c", configuration,
               "--swift-sdk", SDK_NAME, "--triple", TRIPLE, "--scratch-path", str(SCRATCH)]
    if configuration == "release":
        command += ["-Xswiftc", "-enable-testing"]
    command.append(f"+{SWIFT_VERSION}")
    with log.open("w") as output:
        status = subprocess.run(command, cwd=ROOT, env={**os.environ, "ANDROID_NDK_HOME": str(ndk)},
                                stdout=output, stderr=subprocess.STDOUT).returncode
    text = log.read_text(errors="replace")
    warnings = sorted({line for line in text.splitlines()
                       if FIRST_PARTY_WARNING.search(line) and "/.build/" not in line.split(":")[0]})
    if status != 0 or warnings:
        print(f"build ({configuration}) failed: exit {status}, {len(warnings)} warnings in this repository; see {log}")
        for warning in warnings[:10]:
            print("  " + ANSI.sub("", warning))
        return None
    products = SCRATCH / "out" / "Products" / f"{configuration.capitalize()}-android-aarch64"
    if not products.is_dir():
        print(f"build ({configuration}) wrote no products at {products}")
        return None
    return products


def run_on_device(adb, products, runtime, libcxx, configuration):
    """Pushes and runs every test runner; returns whether all passed."""
    def shell(command):
        return subprocess.run([adb, "shell", command], capture_output=True, text=True, errors="replace")

    shell(f"rm -rf {DEVICE_DIRECTORY} && mkdir -p {DEVICE_DIRECTORY}")
    runners = sorted(products.glob("*-test-runner"))
    files = sorted(runtime.glob("*.so")) + [libcxx] + sorted(products.glob("*.so")) + runners
    for file in files:
        pushed = subprocess.run([adb, "push", str(file), f"{DEVICE_DIRECTORY}/"], capture_output=True, text=True)
        if pushed.returncode != 0:
            print(f"adb push {file.name} failed: {pushed.stderr.strip()}")
            return False
    shell(f"chmod 755 {DEVICE_DIRECTORY}/*-test-runner")
    passed = True
    for runner in runners:
        result = shell(f"cd {DEVICE_DIRECTORY} && LD_LIBRARY_PATH={DEVICE_DIRECTORY} "
                       f"./{runner.name} --testing-library swift-testing 2>&1; echo exit=$?")
        output = ANSI.sub("", result.stdout)
        (LOGS / f"{runner.name}-{configuration}.log").write_text(output)
        summary = next((line for line in output.splitlines() if "Test run with" in line), "no Swift Testing run")
        status = re.search(r"exit=(\d+)\s*$", output)
        ok = status is not None and status.group(1) == "0" and "Test run with" in output and "✘" not in output
        passed = passed and ok
        print(f"{configuration} {runner.name}: {'ok' if ok else 'FAILED'}: {summary.strip()}")
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-c", "--configuration", choices=["debug", "release"], default="debug")
    arguments = parser.parse_args()

    ndk = environment_path("ANDROID_NDK_HOME", "Library/Android/ndk/android-ndk-r30")
    android_home = environment_path("ANDROID_HOME", "Library/Android/sdk")
    adb = str(android_home / "platform-tools" / "adb")
    swiftpm_sdks = pathlib.Path.home() / "Library" / "org.swift.swiftpm" / "swift-sdks"
    runtime = (swiftpm_sdks / f"{SDK_NAME}.artifactbundle" / "swift-android" / "swift-resources"
               / "usr" / "lib" / "swift-aarch64" / "android")
    libcxx = (ndk / "toolchains" / "llvm" / "prebuilt" / "darwin-x86_64" / "sysroot" / "usr" / "lib"
              / "aarch64-linux-android" / "libc++_shared.so")
    for required, what in [(ndk, "the Android NDK (ANDROID_NDK_HOME)"), (runtime, f"the {SDK_NAME} Swift SDK"),
                           (libcxx, "the NDK's libc++_shared.so"), (pathlib.Path(adb), "adb (ANDROID_HOME)")]:
        if not required.exists():
            sys.exit(f"Missing {what}: {required}")
    devices = subprocess.run([adb, "devices"], capture_output=True, text=True).stdout.splitlines()[1:]
    if not any(line.strip().endswith("device") for line in devices):
        sys.exit("No emulator or device on adb: boot one (emulator -avd <name> -no-window) first.")

    products = build(arguments.configuration, ndk)
    if products is None:
        sys.exit(1)
    if not run_on_device(adb, products, runtime, libcxx, arguments.configuration):
        sys.exit(1)
    print("All targets passed.")


if __name__ == "__main__":
    main()
