"""Exercise validator behavior with fake Apple tools; no Apple builds are run."""

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import plistlib
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'validate_ios27.py'
spec = importlib.util.spec_from_file_location('validation', SCRIPT)
module = importlib.util.module_from_spec(spec)
with patch.object(sys, 'dont_write_bytecode', True):
    spec.loader.exec_module(module)

STUB = '''#!/usr/bin/env python3
import json, os, pathlib, plistlib, sys
args = sys.argv[1:]
scenario = os.environ.get('VALIDATION_SCENARIO', 'success')
if pathlib.Path(sys.argv[0]).name == 'xcodebuild':
    if args == ['-version']:
        print('Xcode ' + ('26.3' if scenario == 'old_xcode' else '27.0'))
        sys.exit(0)
    if '-showBuildSettings' in args:
        # Mirrors Configuration/SDKConditions.xcconfig for the reported SDK.
        conditions = ['DEBUG'] if args[args.index('-configuration') + 1] == 'Debug' else []
        if scenario in ('sdk_27_1', 'flag_unexpected'):
            conditions.append('YAHT_IOS27_1_SDK')
        print(json.dumps([
            {'target': 'YahtTests', 'buildSettings': {}},
            {'target': 'Yaht', 'buildSettings': {'SWIFT_ACTIVE_COMPILATION_CONDITIONS': ' '.join(conditions)}},
        ]))
        sys.exit(0)
    # The project, not the command line, must supply SDK conditions.
    if any('YAHT_IOS27_1_SDK' in argument for argument in args):
        sys.exit(66)
    if scenario == 'build_failure':
        sys.exit(65)
    configuration = args[args.index('-configuration') + 1]
    root = pathlib.Path(args[args.index('-derivedDataPath') + 1])
    path = root / 'Build' / 'Products' / (configuration + '-iphonesimulator') / 'Yaht.app' / 'Info.plist'
    path.parent.mkdir(parents=True)
    info = {'UILaunchScreen': {}, 'UIApplicationSceneManifest': {}}
    if scenario == 'missing_launch':
        del info['UILaunchScreen']
    if scenario == 'missing_scene':
        del info['UIApplicationSceneManifest']
    with path.open('wb') as output:
        plistlib.dump(info, output)
    if '-resultBundlePath' in args:
        pathlib.Path(args[args.index('-resultBundlePath') + 1]).mkdir()
    print('STUB BUILD - no Apple build performed')
else:
    if args[:2] == ['--sdk', 'iphonesimulator']:
        print('26.4' if scenario == 'old_sdk' else ('27.1' if scenario in ('sdk_27_1', 'flag_missing_27_1') else '27.0'))
    elif args[:3] == ['simctl', 'list', 'devices']:
        print(json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [{'udid':'test-id', 'isAvailable': True}]}}))
    elif args[:3] == ['simctl', 'list', 'runtimes']:
        print(json.dumps({'runtimes': [{'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0', 'version': '26.0' if scenario == 'old_runtime' else '27.0', 'isAvailable': True}]}))
    else:
        if scenario == 'summary_failure':
            sys.exit(74)
        summary = {'totalTestCount': 30, 'passedTests': 30, 'failedTests': 0}
        if scenario == 'zero_tests':
            summary = {'totalTestCount': 0, 'passedTests': 0, 'failedTests': 0}
        if scenario == 'failed_tests':
            summary = {'totalTestCount': 30, 'passedTests': 29, 'failedTests': 1}
        if scenario == 'all_skipped':
            summary = {'totalTestCount': 30, 'passedTests': 0, 'failedTests': 0}
        if scenario == 'unknown_summary':
            summary = {'newField': 30}
        print(json.dumps(summary))
'''

class ValidationTests(unittest.TestCase):
    def test_linux_fails_before_tools(self):
        with patch.object(module.platform, 'system', return_value='Linux'):
            with self.assertRaisesRegex(module.ValidationError, 'requires macOS'):
                module.main(['platform=iOS Simulator,id=test-id'])

    def test_launch_key_variants_and_missing_scene(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'Info.plist'
            variants = [
                ('UILaunchScreen', {}),
                ('UILaunchScreens', {'UILaunchScreenDefinitions': [{}]}),
                ('UILaunchStoryboardName', 'Launch'),
                ('UILaunchStoryboards', {'UILaunchStoryboardDefinitions': [{}]}),
            ]
            for key, value in variants:
                path.write_bytes(plistlib.dumps({key: value, 'UIApplicationSceneManifest': {}}))
                module.check_app_plist(path)
            path.write_bytes(plistlib.dumps({'UILaunchScreen': {}}))
            with self.assertRaisesRegex(module.ValidationError, 'scene lifecycle'):
                module.check_app_plist(path)

    def test_subprocess_scenarios(self):
        scenarios = {
            'success': 0,
            'sdk_27_1': 0,
            'flag_missing_27_1': 1,
            'flag_unexpected': 1,
            'old_xcode': 1,
            'old_sdk': 1,
            'old_runtime': 1,
            'build_failure': 65,
            'summary_failure': 74,
            'missing_launch': 1,
            'missing_scene': 1,
            'zero_tests': 1,
            'failed_tests': 1,
            'all_skipped': 1,
            'unknown_summary': 1,
        }
        for scenario, expected in scenarios.items():
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as root:
                root = Path(root)
                for tool in ('xcodebuild', 'xcrun'):
                    path = root / tool
                    path.write_text(STUB)
                    path.chmod(0o755)
                outputs = []
                def fresh_output(prefix):
                    output = root / (prefix + str(len(outputs)))
                    output.mkdir()
                    outputs.append(output)
                    return str(output)
                stdout = io.StringIO()
                stderr = io.StringIO()
                environment = {
                    'PATH': str(root) + os.pathsep + os.environ['PATH'],
                    'VALIDATION_SCENARIO': scenario,
                }
                with contextlib.ExitStack() as stack:
                    stack.enter_context(patch('platform.system', return_value='Darwin'))
                    stack.enter_context(patch.dict(os.environ, environment))
                    stack.enter_context(patch.object(
                        sys, 'argv', [str(SCRIPT), 'platform=iOS Simulator,id=test-id'],
                    ))
                    stack.enter_context(patch('tempfile.mkdtemp', side_effect=fresh_output))
                    stack.enter_context(contextlib.redirect_stdout(stdout))
                    stack.enter_context(contextlib.redirect_stderr(stderr))
                    with self.assertRaises(SystemExit) as result:
                        runpy.run_path(str(SCRIPT), run_name='__main__')
                self.assertEqual(result.exception.code, expected, stderr.getvalue())
                if scenario in ('success', 'sdk_27_1'):
                    self.assertTrue((outputs[0] / 'Debug.log').exists())
                    self.assertTrue((outputs[0] / 'Release.log').exists())
                    self.assertTrue((outputs[0] / 'Tests.xcresult').exists())
                    self.assertTrue((outputs[0] / 'test-summary.json').exists())
                if scenario == 'build_failure':
                    self.assertFalse((outputs[0] / 'Release.log').exists())
                if scenario in ('zero_tests', 'failed_tests', 'all_skipped', 'unknown_summary'):
                    self.assertTrue((outputs[0] / 'test-summary.json').exists())

if __name__ == '__main__':
    unittest.main(verbosity=2)
