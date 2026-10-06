import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ci"))

from pick_simulator import pick  # noqa: E402


def runtime(version, available=True, platform="iOS"):
    return {
        "identifier": f"com.apple.CoreSimulator.SimRuntime.{platform}-{version.replace('.', '-')}",
        "version": version,
        "isAvailable": available,
    }


def device(name, udid, available=True):
    return {"name": name, "udid": udid, "isAvailable": available}


class PickSimulatorTests(unittest.TestCase):
    def setUp(self):
        self.runtimes = {"runtimes": [
            runtime("26.2"), runtime("26.5"), runtime("27.1"), runtime("27.0", available=False),
            runtime("26.0", platform="watchOS"),
        ]}
        self.devices = {"devices": {
            runtime("26.2")["identifier"]: [device("iPhone 17", "A")],
            runtime("26.5")["identifier"]: [
                device("iPad Pro", "B"), device("iPhone 17 Pro", "C"), device("iPhone 17", "D"),
            ],
            runtime("27.1")["identifier"]: [device("iPhone 18", "E", available=False)],
            runtime("27.0")["identifier"]: [device("iPhone 18", "F")],
        }}

    def test_picks_newest_runtime_in_range_then_first_iphone_by_name(self):
        version, chosen = pick(self.devices, self.runtimes, (26,), (26,))
        self.assertEqual(version, (26, 5))
        self.assertEqual(chosen["udid"], "D")

    def test_skips_unavailable_runtimes_and_devices(self):
        self.assertIsNone(pick(self.devices, self.runtimes, (27,)))

    def test_minor_bounds_cap_runtime_to_the_selected_sdk(self):
        runtimes = {"runtimes": [runtime("27.0"), runtime("27.1"), runtime("27.2")]}
        devices = {"devices": {
            runtime(v)["identifier"]: [device("iPhone 18", v)] for v in ("27.0", "27.1", "27.2")
        }}
        version, chosen = pick(devices, runtimes, (27, 1), (27, 1))
        self.assertEqual((version, chosen["udid"]), ((27, 1), "27.1"))
        self.assertIsNone(pick(devices, runtimes, (27, 3)))

    def test_returns_none_without_matching_runtime(self):
        self.assertIsNone(pick(self.devices, self.runtimes, (28,)))

    def test_ignores_non_iphone_and_other_platforms(self):
        devices = {"devices": {runtime("26.5")["identifier"]: [device("iPad Air", "X")]}}
        self.assertIsNone(pick(devices, self.runtimes, (26,)))


if __name__ == "__main__":
    unittest.main()
