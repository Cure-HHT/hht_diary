#!/usr/bin/env python3
# Plugin Test Runner

import os
import json
import sys

tests_passed = 0
tests_failed = 0

def run_test(name, test_fn):
    global tests_passed, tests_failed
    print(f"Running: {name}... ", end="")
    try:
        if test_fn():
            print("\033[32mPASSED\033[0m")
            tests_passed += 1
        else:
            print("\033[31mFAILED\033[0m")
            tests_failed += 1
    except Exception as e:
        print(f"\033[31mFAILED\033[0m {str(e)}")
        tests_failed += 1

# Metadata Tests
print("=== Metadata Tests ===")
run_test("Plugin.json exists", lambda: os.path.exists(".claude-plugin/plugin.json"))

def validate_plugin_json():
    with open(".claude-plugin/plugin.json", "r") as f:
        data = json.load(f)
    return all([
        data.get("name"),
        data.get("version"),
        data.get("description"),
        data.get("author")
    ])

run_test("Valid plugin.json", validate_plugin_json)

# Summary
print("\n=== Test Summary ===")
print(f"Tests Passed: {tests_passed}")
print(f"Tests Failed: {tests_failed}")

if tests_failed == 0:
    print("\033[32mAll tests passed!\033[0m")
    sys.exit(0)
else:
    print("\033[31mSome tests failed.\033[0m")
    sys.exit(1)