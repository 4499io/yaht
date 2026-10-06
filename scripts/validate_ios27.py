#!/usr/bin/env python3
"""Build and test Yaht with a locally installed iOS 27 simulator toolchain."""

import argparse
import json
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


class ValidationError(Exception):
    pass


def run(command, log_path=None):
    """Keep tool failures intact; never hide an xcodebuild failure behind tee."""
    print("+ " + shlex.join(map(str, command)), flush=True)
    if log_path is None:
        result = subprocess.run(command, check=True, text=True, capture_output=True)
        return result.stdout
    with log_path.open("w") as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    return ""


def require_major(version, minimum, label):
    match = re.match(r"(\d+)(?:\.\d+)*\b", version.strip())
    if match is None or int(match.group(1)) < minimum:
        raise ValidationError(f"{label} must be {minimum} or later; found {version.strip()!r}.")


def check_app_plist(path):
    with path.open("rb") as source:
        info = plistlib.load(source)
    # An empty UILaunchScreen dictionary is valid for a generated launch screen.
    has_launch_screen = isinstance(info.get("UILaunchScreen"), dict)
    has_storyboard = isinstance(info.get("UILaunchStoryboardName"), str) and bool(
        info["UILaunchStoryboardName"].strip()
    )
    has_launch_screens = isinstance(info.get("UILaunchScreens"), dict) and bool(info["UILaunchScreens"])
    has_storyboards = isinstance(info.get("UILaunchStoryboards"), dict) and bool(info["UILaunchStoryboards"])
    if not (has_launch_screen or has_storyboard or has_launch_screens or has_storyboards):
        raise ValidationError(f"Missing launch-screen configuration in {path}.")
    if not isinstance(info.get("UIApplicationSceneManifest"), dict):
        raise ValidationError(f"Missing scene lifecycle manifest in {path}.")
    print(f"Verified launch-screen and scene lifecycle keys: {path}", flush=True)


def check_sdk_conditions(settings_json, sdk_version):
    """Configuration/SDKConditions.xcconfig must set the flag exactly for SDK 27.1+."""
    targets = [entry for entry in json.loads(settings_json) if entry.get("target") == "Yaht"]
    if not targets:
        raise ValidationError("xcodebuild -showBuildSettings reported no Yaht target.")
    conditions = targets[0].get("buildSettings", {}).get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "").split()
    expected = sdk_version >= (27, 1)
    if ("YAHT_IOS27_1_SDK" in conditions) != expected:
        raise ValidationError(
            f"YAHT_IOS27_1_SDK should be {'set' if expected else 'unset'} for SDK "
            f"{sdk_version[0]}.{sdk_version[1]}; active conditions: {conditions}."
        )
    print(f"Active compilation conditions: {' '.join(conditions)}", flush=True)


def check_test_summary(summary):
    # xcresulttool's test-results summary fields; fail closed if the schema changes.
    fields = ("totalTestCount", "passedTests", "failedTests")
    if not isinstance(summary, dict) or any(type(summary.get(field)) is not int for field in fields):
        raise ValidationError(
            "Unrecognized xcresult summary: expected integer totalTestCount, "
            "passedTests and failedTests. Inspect the saved summary and installed "
            "xcresulttool help before updating this check."
        )
    if summary["totalTestCount"] <= 0 or summary["passedTests"] <= 0 or summary["failedTests"] != 0:
        raise ValidationError("The xcresult must contain executed, passing tests and no failures.")
    print(
        f"Tests: {summary['passedTests']} passed, {summary['failedTests']} failed, "
        f"{summary['totalTestCount']} total.",
        flush=True,
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "destination",
        help="Installed iOS 27+ simulator destination, e.g. platform=iOS Simulator,id=<UDID>",
    )
    args = parser.parse_args(argv)
    if platform.system() != "Darwin":
        raise ValidationError("This validation requires macOS, Xcode 27+ and an iOS 27+ simulator.")
    for tool in ("xcodebuild", "xcrun"):
        if shutil.which(tool) is None:
            raise ValidationError(f"{tool} is unavailable; select a full Xcode 27+ installation.")
    destination = dict(part.strip().split("=", 1) for part in args.destination.split(","))
    if destination.get("platform") != "iOS Simulator" or not destination.get("id"):
        raise ValidationError("Supply platform=iOS Simulator,id=<UDID> for an installed simulator.")

    version = run(["xcodebuild", "-version"])
    match = re.search(r"^Xcode (.+)$", version, flags=re.MULTILINE)
    require_major(match.group(1) if match else version, 27, "Xcode")
    sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"])
    require_major(sdk, 27, "iPhone simulator SDK")
    sdk_match = re.match(r"(\d+)(?:\.(\d+))?", sdk.strip())
    sdk_version = (int(sdk_match.group(1)), int(sdk_match.group(2) or 0))
    devices = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "--json"]))
    runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "--json"]))
    runtime_id = next((
        runtime for runtime, entries in devices["devices"].items()
        if any(device["udid"] == destination["id"] and device.get("isAvailable") for device in entries)
    ), None)
    runtime = next((entry for entry in runtimes["runtimes"] if entry["identifier"] == runtime_id), None)
    if runtime is None or not runtime.get("isAvailable") or ".iOS-" not in runtime["identifier"]:
        raise ValidationError("The destination must identify an available iOS simulator runtime.")
    require_major(runtime["version"], 27, "Destination iOS runtime")

    repository = Path(__file__).resolve().parent.parent
    output = Path(tempfile.mkdtemp(prefix="yaht-ios27-"))
    print(f"Fresh validation outputs (retained): {output}", flush=True)
    common = [
        "xcodebuild", "-project", str(repository / "Yaht.xcodeproj"), "-scheme", "Yaht",
        "-sdk", "iphonesimulator", "-destination", args.destination,
        "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=",
        "COMPILER_INDEX_STORE_ENABLE=NO",
    ]
    for configuration, action in (("Debug", "test"), ("Release", "build")):
        settings = run([
            "xcodebuild", "-project", str(repository / "Yaht.xcodeproj"), "-scheme", "Yaht",
            "-sdk", "iphonesimulator", "-configuration", configuration, "-showBuildSettings", "-json",
        ])
        check_sdk_conditions(settings, sdk_version)
        derived = output / configuration
        command = common + [
            "-configuration", configuration, "-derivedDataPath", str(derived), action,
        ]
        if action == "test":
            command += [
                "-parallel-testing-enabled", "NO", "-resultBundlePath", str(output / "Tests.xcresult"),
            ]
        log = output / f"{configuration}.log"
        print(f"{configuration} output: {log}", flush=True)
        run(command, log)
        check_app_plist(derived / "Build" / "Products" / f"{configuration}-iphonesimulator" / "Yaht.app" / "Info.plist")
        if action == "test":
            summary_text = run([
                "xcrun", "xcresulttool", "get", "test-results", "summary",
                "--path", str(output / "Tests.xcresult"), "--compact",
            ])
            (output / "test-summary.json").write_text(summary_text)
            check_test_summary(json.loads(summary_text))
    print(f"SDK build/test/plist checks passed. Manual runtime checks remain: see docs/IOS27_VALIDATION.md. Outputs: {output}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        if error.stdout:
            print(error.stdout, file=sys.stderr)
        if error.stderr:
            print(error.stderr, file=sys.stderr)
        print(f"Tool failed with exit status {error.returncode}: {shlex.join(map(str, error.cmd))}", file=sys.stderr)
        sys.exit(error.returncode if error.returncode >= 0 else 128 - error.returncode)
    except (ValidationError, OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException) as error:
        print(f"Validation failed: {error}", file=sys.stderr)
        sys.exit(1)
