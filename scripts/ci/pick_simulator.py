#!/usr/bin/env python3
"""Print an xcodebuild destination for an installed iPhone simulator.

CI runner images change their simulator set without notice, so CI asks the
selected Xcode which runtimes exist instead of hard-coding a device name.
Picks the newest iOS runtime within [--min-major, --max-major], then the first
available iPhone on it by name, and prints `platform=iOS Simulator,id=<UDID>`.
"""

import argparse
import json
import re
import subprocess
import sys


def parse_version(text):
    return tuple(int(part) for part in re.findall(r"\d+", text)[:3])


def pick(devices, runtimes, min_major, max_major=None):
    candidates = []
    for runtime in runtimes.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        if ".iOS-" not in identifier or not runtime.get("isAvailable"):
            continue
        version = parse_version(runtime.get("version", ""))
        if not version or version[0] < min_major or (max_major is not None and version[0] > max_major):
            continue
        iphones = sorted(
            (device for device in devices.get("devices", {}).get(identifier, [])
             if device.get("isAvailable") and device.get("name", "").startswith("iPhone")),
            key=lambda device: device["name"],
        )
        if iphones:
            candidates.append((version, iphones[0]))
    if not candidates:
        return None
    candidates.sort(key=lambda candidate: candidate[0])
    return candidates[-1]


def simctl_json(*args):
    output = subprocess.run(
        ["xcrun", "simctl", "list", *args, "--json"], check=True, text=True, capture_output=True
    ).stdout
    return json.loads(output)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min-major", type=int, required=True)
    parser.add_argument("--max-major", type=int)
    args = parser.parse_args(argv)
    choice = pick(simctl_json("devices", "available"), simctl_json("runtimes"), args.min_major, args.max_major)
    if choice is None:
        bound = f"{args.min_major}" + (f"-{args.max_major}" if args.max_major is not None else "+")
        print(f"No available iPhone simulator with an iOS {bound} runtime.", file=sys.stderr)
        return 1
    version, device = choice
    print(f"Selected {device['name']} (iOS {'.'.join(map(str, version))})", file=sys.stderr)
    print(f"platform=iOS Simulator,id={device['udid']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
