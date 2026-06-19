# Firebase Test Lab from GitHub Actions

## Purpose

The `Firebase Test Lab` workflow builds and runs the Clinical Diary mobile
smoke test against the Cure HHT work Test Lab project:

- Google Cloud/Firebase project: `cure-hht-qa`
- Console: `https://console.firebase.google.com/project/cure-hht-qa/testlab`
- Workflow: `.github/workflows/firebase-test-lab.yml`

The workflow is manual-only while the first device matrices are being proven.
It does not publish to Google Play or TestFlight.

## Architecture decision

The store workflows remain unchanged:

- `.github/workflows/android-build.yml`
- `.github/workflows/ios-build.yml`

Their pinned Flutter, Java, Ruby, CocoaPods, CMake, artifact-retention, and
Google Workload Identity Federation patterns are reused. Their output artifacts
are **not** transformed into test artifacts, because:

- Android instrumentation requires an application APK compiled for the selected
  integration-test target plus a separate `androidTest` APK.
- iOS XCTest requires a ZIP containing the physical-device app/test products
  and an `.xctestrun` file. A distribution IPA is not that package.
- Both store workflows have version/upload gates that are correct for stores but
  inappropriate for repeatable regression testing of the same commit.

The new workflow therefore builds test inputs directly from the same source
revision without invoking either store deployment.

## Migrated automation

Reusable concepts retained from the former Windows/AWS Device Farm automation:

- Flutter `integration_test` entrypoint.
- Android application and instrumentation APK pairing.
- Native Android test bridge.
- iOS `build-for-testing` and `.xctestrun` packaging.
- Logs, build metadata, SHA-256 hashes, and downloadable evidence.

AWS-specific items intentionally not migrated:

- AWS account IDs and ARNs.
- Device Farm projects, device pools, uploads, schedules, and polling.
- Appium custom-environment package.
- Local absolute Windows paths.
- Locally cached credentials or CLI login state.
- The custom JSON-file polling Android harness. Flutter's supported
  `FlutterTestRunner` now reports Dart test cases directly through JUnit.

## Test source

The initial deterministic smoke test is:

`apps/daily-diary/clinical_diary/integration_test/firebase_test_lab_smoke_test.dart`

It verifies that the app:

1. Completes native/Flutter startup.
2. Initializes device-local storage.
3. Renders the `MaterialApp` and `HomeScreen`.
4. Produces a screenshot.
5. Survives a pause/resume lifecycle transition.

It uses an unlinked local state and does not require patient credentials,
participant identifiers, PHI, or production records.

## Android build

Android uses a debug build so the application APK and test APK share compatible
debug signing.

The build script is:

```text
firebase-test-lab/scripts/build-android.sh
```

Conceptually it runs:

```bash
flutter build apk \
  --debug \
  --flavor qa \
  --target integration_test/firebase_test_lab_smoke_test.dart

cd android
./gradlew \
  :app:assembleQaDebugAndroidTest \
  :app:assembleQaDebug \
  -Ptarget="$PWD/../integration_test/firebase_test_lab_smoke_test.dart"
```

Outputs:

```text
apps/daily-diary/clinical_diary/build/firebase-test-lab/android/
  app-qa-debug.apk
  app-qa-debug-androidTest.apk
  build-metadata.txt
  test-manifest.xml
```

The test bridge is:

```text
android/app/src/androidTest/java/org/curehht/clinical_diary/MainActivityTest.java
```

It uses Flutter's `FlutterTestRunner`. The Android Gradle configuration declares
`AndroidJUnitRunner` and current stable AndroidX Test dependencies.

## iOS build

The iOS build script is:

```text
firebase-test-lab/scripts/build-ios.sh
```

The checked-in Xcode target currently contains a default Swift unit-test stub.
For the CI checkout only, the script replaces that source-file reference with
Flutter's Objective-C integration-test runner:

```text
firebase-test-lab/ios/RunnerTests.m
```

The production Xcode project is restored when the build script exits.

The script:

1. Stamps `assets/config/env.json` for the selected flavor.
2. Copies the selected flavor's `GoogleService-Info.plist` into the Runner.
3. Builds Flutter using the integration-test target.
4. Runs `xcodebuild build-for-testing` for physical iOS devices.
5. Packages `Release-iphoneos` and `Runner_*.xctestrun` into an XCTest ZIP.

Output:

```text
apps/daily-diary/clinical_diary/build/firebase-test-lab/ios/
  ios-qa-xctest.zip
  build-metadata.txt
  xcodebuild.log
  zip-contents.txt
```

## Firebase project versus app backend

The test matrix is submitted to `cure-hht-qa`.

The QA application's checked-in native Firebase configuration currently points
to `cure-hht-admin`. These are separate concerns:

- `cure-hht-qa` owns the Test Lab matrix, quota, and results.
- The app's native configuration controls the backend/FCM project used at
  runtime.

This workflow does not silently change the app backend. Any backend migration
must be reviewed as a separate application/configuration change.

## GitHub repository configuration

The workflow reuses the repository variables already referenced by the Android
store workflow:

| Variable | Purpose |
|---|---|
| `GCP_PROJECT_NUMBER` | Project number embedded in the existing Workload Identity Provider resource path |
| `GCP_SA_EMAIL` | Service account impersonated by GitHub Actions |

Optional repository variable:

| Variable | Purpose |
|---|---|
| `FIREBASE_TEST_LAB_RESULTS_BUCKET` | User-owned Cloud Storage bucket for Test Lab results. The workflow accepts either a bucket name or a `gs://` prefix. |

No service-account JSON key is used or committed.

## Google Cloud permissions

The service account identified by `GCP_SA_EMAIL` must be allowed to run tests in
`cure-hht-qa`.

For a user-owned results bucket, grant both project roles:

```text
roles/cloudtestservice.testAdmin
roles/firebase.analyticsViewer
```

Also grant the service account the minimum required object permissions on the
specific results bucket, normally through a bucket-level role such as
`roles/storage.objectAdmin` after review by the cloud administrator.

Firebase's default Test Lab results bucket has broader IAM requirements. The
Firebase documentation currently specifies `roles/editor` for gcloud-based
execution using that default bucket. For least privilege, prefer a dedicated
results bucket and the granular Test Lab roles above.

The Workload Identity Federation principal also needs permission to impersonate
the selected service account (`roles/iam.workloadIdentityUser`) under the same
repository restrictions already used by the existing Android workflow.

## Manual execution

1. Open **Actions** in GitHub.
2. Select **Firebase Test Lab**.
3. Select **Run workflow**.
4. Choose:
   - `platform`: `android`, `ios`, or `both`
   - `flavor`: normally `qa`
   - `timeout`: normally `15m`
   - `use_orchestrator`: start with `false`
5. Leave device inputs blank for the Firebase default device, or enter one
   device specification per line.

Android example:

```text
model=Pixel2,version=30,locale=en,orientation=portrait
```

The workflow retrieves the current model/version inventory before submitting a
matrix. Device IDs should be selected from those live lists rather than assumed
to remain available permanently.

For iOS, `ios_xcode_version` is optional. Set it only to a version shown as
supported by the current Firebase iOS model/version inventory.

## Test Lab commands

Android execution is structurally:

```bash
gcloud firebase test android run \
  --project=cure-hht-qa \
  --type=instrumentation \
  --app=app-qa-debug.apk \
  --test=app-qa-debug-androidTest.apk \
  --timeout=15m \
  --results-dir=<unique-run-directory>
```

iOS execution is structurally:

```bash
gcloud firebase test ios run \
  --project=cure-hht-qa \
  --type=xctest \
  --test=ios-qa-xctest.zip \
  --timeout=15m \
  --results-dir=<unique-run-directory>
```

## Exit-code behavior

The workflow captures the gcloud exit code, uploads evidence, writes the job
summary, and only then enforces the final status.

| Exit code | Meaning used by the workflow |
|---:|---|
| `0` | All test executions passed |
| `10` | One or more test cases failed |
| `15` | Test matrix was indeterminate or encountered infrastructure trouble |
| `19` | Test matrix was canceled |
| Other | Command/setup failure; inspect `gcloud-output.log` |

## Evidence

GitHub artifacts are retained for 90 days and include:

- Application/test APKs or XCTest ZIP.
- Input hashes and build metadata.
- Current Firebase device and version inventories.
- Exact gcloud command used.
- gcloud console output.
- Exit code.
- Execution summary JSON.
- Xcode build log and ZIP contents for iOS.

When `FIREBASE_TEST_LAB_RESULTS_BUCKET` is configured, the workflow also tries
to copy the complete Firebase result tree into the GitHub evidence artifact.
Firebase retains its native logs, screenshots, video, test cases, and
performance results according to the Test Lab project/bucket retention policy.

## Clinical-data safety

- Use only `dev`, `qa`, or `uat` builds.
- Do not add production as a workflow option.
- Do not place patient credentials in workflow inputs.
- Use dedicated synthetic test accounts for future authenticated tests.
- Review screenshots, videos, logs, and downloaded Test Lab artifacts before
  using them as validation evidence.
- Never enter real patient information or PHI in automated test data.

## Local reproduction

From the repository root on Linux/macOS or a suitable Git Bash/WSL environment:

```bash
firebase-test-lab/scripts/build-android.sh qa
```

On a macOS host with the pinned Flutter/Ruby/CocoaPods/Xcode toolchain:

```bash
firebase-test-lab/scripts/build-ios.sh qa
```

After authenticating gcloud to the approved work service account/project:

```bash
export GCP_PROJECT_ID=cure-hht-qa
export FLAVOR=qa
export TEST_TIMEOUT=15m
export RESULTS_DIR="hht-diary/local/android-$(date +%s)"
export APP_APK="apps/daily-diary/clinical_diary/build/firebase-test-lab/android/app-qa-debug.apk"
export TEST_APK="apps/daily-diary/clinical_diary/build/firebase-test-lab/android/app-qa-debug-androidTest.apk"
firebase-test-lab/scripts/run-android-test-lab.sh
```

## Cost and quota safeguards

- The workflow is manual-only.
- Blank device inputs use one Firebase default configuration.
- Multi-device matrices require explicit device lines.
- Per-device timeout defaults to 15 minutes.
- Android Orchestrator is disabled by default until locally proven.
- A concurrency group prevents overlapping runs for the same branch, platform,
  and flavor.

## Troubleshooting

### Authentication succeeds but Test Lab submission is denied

Confirm the service account has roles in `cure-hht-qa`, not only in the project
that hosts the service account or the app backend.

### Android test APK is missing

Confirm:

- `integration_test` remains in `dev_dependencies`.
- `MainActivityTest.java` is present under `src/androidTest`.
- `testInstrumentationRunner` is configured.
- The flavor task exists, for example `assembleQaDebugAndroidTest`.

### Android test launches but reports zero tests

Confirm the application APK was built with the same `-Ptarget` integration-test
file used to build the test APK. Do not pair a normal store APK with the test
APK.

### iOS ZIP is rejected

Inspect `zip-contents.txt`. The archive must include:

- `Release-iphoneos/Runner.app`
- `Release-iphoneos/RunnerTests.xctest`
- `Runner_*.xctestrun`

Also confirm the Xcode version used by the GitHub runner is supported for the
selected Test Lab iOS version, setting `ios_xcode_version` when necessary.

### QA app talks to an unexpected Firebase backend

That behavior comes from the app's `GoogleService-Info.plist` or
`google-services.json`, not the Test Lab project passed to gcloud. Treat a
backend-project change as a separate reviewed change.

## Rollback

Rollback consists of reverting:

- `.github/workflows/firebase-test-lab.yml`
- `firebase-test-lab/`
- the integration-test entrypoint
- the Android `MainActivityTest.java`
- the instrumentation additions in `android/app/build.gradle.kts`

No existing store workflow or production deployment is changed by this
implementation.
