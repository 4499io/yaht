#!/usr/bin/env python3
"""Print an xcodebuild destination for an installed iPhone simulator.

CI runner images change their simulator set without notice, so CI asks the
selected Xcode which runtimes exist instead of hard-coding a device name.
Picks the newest iOS runtime within [--min, --max], then the first available
iPhone on it by name, and prints `platform=iOS Simulator,id=<UDID>`. A bound
compares only the components it names: `--max 26` admits 26.5, `--max 27.1`
rejects 27.2.
"""

import argparse
import json
import re
import subprocess
import sys


def parse_version(text):
    return tuple(int(part) for part in re.findall(r"\d+", text)[:3])


def within(version, minimum, maximum):
    if version[:len(minimum)] < minimum:
        return False
    return maximum is None or version[:len(maximum)] <= maximum


def pick(devices, runtimes, minimum, maximum=None):
    candidates = []
    for runtime in runtimes.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        if ".iOS-" not in identifier or not runtime.get("isAvailable"):
            continue
        version = parse_version(runtime.get("version", ""))
        if not version or not within(version, minimum, maximum):
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
    parser.add_argument("--min", type=parse_version, required=True, help="e.g. 26 or 27.1")
    parser.add_argument("--max", type=parse_version, help="e.g. 26 or 27.1")
    args = parser.parse_args(argv)
    devices, runtimes = simctl_json("devices", "available"), simctl_json("runtimes")
    choice = pick(devices, runtimes, args.min, args.max)
    if choice is None:
        # Name what is installed so a runner-image change is diagnosable from the log.
        for runtime in runtimes.get("runtimes", []):
            iphones = sum(
                device.get("name", "").startswith("iPhone")
                for device in devices.get("devices", {}).get(runtime.get("identifier", ""), [])
            )
            print(
                f"  {runtime.get('identifier')} version={runtime.get('version')} "
                f"available={runtime.get('isAvailable')} iphones={iphones}",
                file=sys.stderr,
            )
        show = lambda version: ".".join(map(str, version))
        bound = show(args.min) + (f" to {show(args.max)}" if args.max else "+")
        print(f"No available iPhone simulator with an iOS {bound} runtime (installed runtimes above).", file=sys.stderr)
        return 1
    version, device = choice
    print(f"Selected {device['name']} (iOS {'.'.join(map(str, version))})", file=sys.stderr)
    print(f"platform=iOS Simulator,id={device['udid']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
