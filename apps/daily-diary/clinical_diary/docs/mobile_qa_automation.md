# Mobile QA Automation

This folder contains the starter automation created from the Clinical Diary QA validation plan.

## Layers

1. Flutter source-level integration tests:
   - `integration_test/mobile_qa_smoke_test.dart`
   - Covers launch, home/enrollment reachability, semantic labels, and rapid core navigation.
   - Intended for CI and developer validation against a build generated from source.

2. Release APK black-box evidence runner:
   - `tool/run_mobile_qa_evidence.ps1`
   - Installs an APK, launches the app, captures screenshots/UI dumps/logs, exercises core navigation, and runs a monkey stress pass.
   - Intended for QA validation of a built APK such as `app-dev-release.apk`.

3. Firebase Test Lab instrumentation matrix:
   - `tool/build_ftl_apks.ps1`
   - `tool/run_ftl_device_matrix.ps1`
   - Builds the QA app/test APK pair with visible evidence markers, then runs the 31-test instrumentation suite across the representative Android phone matrix below.

4. Firebase Test Lab iOS XCTest evidence matrix:
   - `tool/build_ios_xctest_device_farm.sh`
   - `tool/run_ftl_ios_matrix.ps1`
   - Builds the hosted XCTest package on macOS with the QA evidence overlay enabled, then runs the iOS XCTest package in Firebase Test Lab.

## Run Flutter Integration Tests

From `hht_diary/apps/daily-diary/clinical_diary`:

```powershell
flutter test integration_test/mobile_qa_smoke_test.dart -d emulator-5554
```

For a connected physical device, replace `emulator-5554` with the device ID from:

```powershell
flutter devices
```

## Run Release APK Evidence Automation

From `hht_diary/apps/daily-diary/clinical_diary`:

```powershell
.\tool\run_mobile_qa_evidence.ps1 `
  -ApkPath ..\..\..\..\..\app-dev-release.apk `
  -PackageName org.anspar.curehht.app.dev `
  -MainActivity org.curehht.clinical_diary.MainActivity `
  -OutDir .\build\qa-evidence
```

Output includes:

- `SUMMARY.txt`
- install/launch command output
- screenshots (`*.png`)
- UI hierarchy dumps (`*.xml`)
- Logcat crash/error extracts
- monkey stress output

## Run Firebase Test Lab Matrix

From `hht_diary/apps/daily-diary/clinical_diary`:

```powershell
.\tool\run_ftl_device_matrix.ps1 -BuildFirst
```

To reuse already-built APKs:

```powershell
.\tool\run_ftl_device_matrix.ps1
```

### Firebase Device Matrix

| Coverage Bucket | Firebase Model ID | Device | Android Version |
|---|---:|---|---:|
| Pixel recent | `frankel` | Pixel 10 | 16 / API 36 |
| Pixel previous | `tokay` | Pixel 9 | 15 / API 35 |
| Pixel older | `panther` | Pixel 7 | 13 / API 33 |
| Samsung Galaxy S older | `r11q` | Galaxy S23 FE | 14 / API 34 |
| Samsung Galaxy A-series | `a56x` | Galaxy A56 5G | 15 / API 35 |
| Samsung Galaxy A-series older | `a12` | Galaxy A12 | 12 / API 31 |
| Motorola midrange | `austin` | moto g 5G (2022) | 13 / API 33 |
| Low-memory Android phone | `guamna` | moto g play (2021) | 11 / API 30 |
| Small-screen Android phone | `SmallPhone.arm` | Small Phone virtual device | 13 / API 33 |
| Non-Google/Samsung OEM | `CPH2449` | OnePlus 11 5G | 14 / API 34 |

## Run Firebase Test Lab iOS XCTest Matrix

The iOS XCTest package must be built on macOS with Xcode installed. From `hht_diary/apps/daily-diary/clinical_diary` on the Mac:

```bash
./tool/build_ios_xctest_device_farm.sh
```

By default, the package is built for the QA flavor and compiles the same Flutter integration target used by the Android Firebase Test Lab APKs:

```text
integration_test/mobile_qa_smoke_test.dart
```

Override the target or flavor when needed:

```bash
FLAVOR=qa INTEGRATION_TARGET=integration_test/mobile_qa_smoke_test.dart ./tool/build_ios_xctest_device_farm.sh
```

Copy the generated XCTest zip back to this checkout if you want to launch Firebase Test Lab from Windows:

```text
build/device-farm/clinical-diary-ios-xctest.zip
```

Then run:

```powershell
.\tool\run_ftl_ios_matrix.ps1
```

The iOS evidence suite writes the same visible QA marker file used by the Flutter overlay. Each XCTest holds a unique marker on screen, such as `NET-001`, `SEC-001`, `A11Y-002`, `LIFE-001`, `TIME-002`, or `FUNC-004`, so Firebase videos are distinguishable even when the underlying app screen is otherwise similar.

### Firebase iOS Device Matrix

| Coverage Bucket | Firebase Model ID | Device | iOS Version |
|---|---:|---|---:|
| iPhone recent | `iphone16pro` | iPhone 16 Pro | 18.3 |
| iPhone compact recent | `iphonese3` | iPhone SE 3 | 18.4 |
| iPhone previous | `iphone14pro` | iPhone 14 Pro | 16.6 |
| iPhone older large | `iphone11pro` | iPhone 11 Pro | 16.6 |
| iPhone older small | `iphone8` | iPhone 8 | 16.6 |
| iPad | `ipad10` | iPad 10th generation | 16.6 |

## Current Coverage

| Plan ID | Automated By | Notes |
|---|---|---|
| SMK-001 | Flutter integration + PowerShell runner | Launch and first interactive screen. |
| SMK-003 | Flutter integration + PowerShell runner | Dashboard/enrollment reachability. |
| SMK-004 | PowerShell runner | Opens Record Nosebleed by coordinate in current layout. |
| REG-005 | PowerShell runner | Calendar, app menu, settings/user menu navigation. |
| A11Y-001 | Flutter integration | Checks for core semantic labels when dashboard controls are visible. |
| PERF-001 | PowerShell runner | Package-scoped monkey run. |
| PERF-003 | Flutter integration | Rapid core navigation without Flutter exception. |

## Next Automation to Add

- Login/enrollment automation once stable QA credentials and clinical trial codes are provided.
- Data-level assertions using backend/portal APIs.
- Offline queue tests using emulator network controls.
- Security scans that fail on known PHI/PII/token patterns in log output.
- Appium or Detox-style black-box selectors if test IDs/semantic labels are added consistently to the Flutter UI.

## Selector Guidance

Prefer semantic labels and stable `Key` values over screen coordinates. The current APK runner uses coordinates for a few controls because the black-box APK surface does not expose Flutter keys to ADB. The Flutter integration tests use semantic labels where available.
