#!/usr/bin/env python3
"""Builds and tests the SwiftPM package on the Apple platforms `just test` doesn't reach.

`just test` covers macOS and the iOS simulator through Bazel. This runs xcodebuild on the package
for the rest:

- watchOS devices, built for testing (arm64_32, whose 32-bit record layout the layout tests pin,
  and arm64); no device runs them;
- the tvOS, watchOS and visionOS simulators, and Mac Catalyst, tested.

Each simulator is the first available device of its platform (`xcrun simctl list`), so the
script works whatever devices the Mac has. Usage: `just apple-test [--platforms tvOS,watchOS]`.
Logs go to `.build/apple/logs/<platform>.log`; a platform fails when xcodebuild does, or when its
log shows a warning from a source in this repository.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DERIVED = ROOT / ".build" / "apple"
LOGS = DERIVED / "logs"

# The simctl runtime prefix and destination platform of each simulator.
SIMULATORS = {
    "tvOS": ("com.apple.CoreSimulator.SimRuntime.tvOS", "tvOS Simulator"),
    "watchOS": ("com.apple.CoreSimulator.SimRuntime.watchOS", "watchOS Simulator"),
    "visionOS": ("com.apple.CoreSimulator.SimRuntime.xrOS", "visionOS Simulator"),
}
PLATFORMS = ["watchOS-device", "tvOS", "watchOS", "visionOS", "Mac Catalyst"]


def first_device(runtime_prefix):
    """The UDID of the first available simulator of a runtime, newest runtime first, or None."""
    listing = json.loads(subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        check=True, capture_output=True, text=True).stdout)
    runtimes = sorted((r for r in listing["devices"] if r.startswith(runtime_prefix)), reverse=True)
    for runtime in runtimes:
        for device in listing["devices"][runtime]:
            return device["udid"]
    return None


def xcodebuild(action, destination, log):
    command = ["xcodebuild", action, "-scheme", "LinkerSets-Package",
               "-destination", destination, "-derivedDataPath", str(DERIVED),
               "-skipPackagePluginValidation", "-skipMacroValidation"]
    with open(log, "w") as out:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT).returncode


def own_warnings(log):
    """Compiler warnings in this repository's sources (Xcode's own tools warn about other things)."""
    pattern = re.compile(rf"^{re.escape(str(ROOT))}/(Sources|Tests)/\S+:\d+:\d+: warning:")
    return sorted({line.strip() for line in open(log, errors="replace") if pattern.match(line)})


def run(platform):
    log = LOGS / f"{platform.replace(' ', '-')}.log"
    if platform == "watchOS-device":
        status = xcodebuild("build-for-testing", "generic/platform=watchOS", log)
    elif platform == "Mac Catalyst":
        status = xcodebuild("test", "platform=macOS,variant=Mac Catalyst", log)
    else:
        runtime, destination = SIMULATORS[platform]
        udid = first_device(runtime)
        if udid is None:
            print(f"{platform}: no simulator installed (Xcode > Settings > Components)")
            return False
        status = xcodebuild("test", f"platform={destination},id={udid}", log)
    warnings = own_warnings(log)
    print(f"{platform}: xcodebuild exit {status}, {len(warnings)} warnings in this repository; log {log}")
    for warning in warnings:
        print(f"  {warning}")
    return status == 0 and not warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--platforms", default=",".join(PLATFORMS),
                        help=f"comma-separated, from {', '.join(PLATFORMS)}")
    platforms = parser.parse_args().platforms.split(",")
    unknown = [p for p in platforms if p not in PLATFORMS]
    if unknown:
        sys.exit(f"unknown platforms: {', '.join(unknown)}")
    LOGS.mkdir(parents=True, exist_ok=True)
    results = [run(p) for p in platforms]
    if not all(results):
        sys.exit(1)
    print("All platforms passed.")


if __name__ == "__main__":
    main()
