## 1. Overview

This document describes two independent GitHub Actions workflows that cover the full lifecycle of releasing a mobile app and managing beta testers for both Android (Google Play) and iOS (App Store Connect / TestFlight), without giving testers any access to the developer consoles.

### Workflow 1 — Release pipeline

Triggers automatically when a version tag (including the build) is pushed to the repository.

- Builds and signs the Android AAB and iOS IPA in parallel.
- Stores both artifacts in GitHub Actions for 90 days.
- Uploads the Android build to the Play Console beta testing and release track.
- Uploads the iOS build to external TestFlight and releases via the App Store Connect API.
- Sends a Slack or email notification when both uploads are complete.

### Workflow 2 — Add tester

Triggered manually via the GitHub Actions `workflow_dispatch` interface.

- Accepts tester details (email, name, group name, platform) as input parameters.
- Checks whether the named group already exists on the selected platform.
- Creates the group automatically if it does not exist.
- Adds the tester to the group. No console login is required.
- Works for Android only, iOS only, or both simultaneously.

The two workflows are completely independent. Releasing does not require the tester workflow, and adding a tester does not require a release. Both share the same GitHub Actions secrets, so configuration is not duplicated.

---

## 2. Workflow 1 — Release pipeline

### Trigger

The workflow runs on every push to `main`. No manual action is required after the tag is pushed.

### Step-by-step process

#### Step 1 — Push release tag

A developer pushes a release tag. GitHub Actions detects the tag and starts the workflow automatically. The Android and iOS jobs begin in parallel.

#### Step 2 — Build Android AAB

A Ubuntu runner checks out the code, sets up Java 17, and runs the Gradle release bundle task. The output AAB is signed using the signing key stored in GitHub Secrets.

#### Step 3 — Build iOS IPA

A macOS runner checks out the code, installs the distribution certificate and provisioning profile from secrets, runs `xcodebuild archive`, and exports a signed IPA.

#### Step 4 — Store artifacts

Both the AAB and IPA are uploaded as GitHub Actions artifacts named with the release tag, for example `android-release-v1.2.3` and `ios-release-v1.2.3`. They are retained for 90 days and can be downloaded at any time for manual re-upload and testing of past releases.

#### Step 5 — Upload to Play Console

The AAB is uploaded as a new edit to the Play Console beta testing and release track using the Google Play Android Publisher API. The edit is committed so the build becomes available immediately. No review is required for the internal track.

#### Step 6 — Upload to TestFlight

The IPA is uploaded to App Store Connect using `xcrun altool` with the API key. The build appears in TestFlight after Apple’s automated processing, which usually takes a few minutes. External testers require a Beta App Review before they can install, which typically takes a few hours.

#### Step 7 — Notify team

A Slack message or email is sent to confirm the release tag, the status for both platforms, and any errors.

---

## 3. Workflow 2 — Add tester

File location in your repository: `.github/workflows/add-tester.yml`

### How to trigger it

Go to GitHub, then **Actions**, then **Add tester to beta group**, then **Run workflow**. A form appears with the following input fields:

| Input field | Description | Example |
|---|---|---|
| email | Tester email address | qa@client.com |
| first_name | Tester first name | John |
| last_name | Tester last name | Smith |
| group_name | Group name (created if it does not exist) | QA Team v1.2 |
| platform | android, ios, or both | both |

### Android path — step by step

#### Step 1 — Authenticate

The runner authenticates to the Google Play Android Publisher API using a service account JSON key stored in GitHub Secrets.

#### Step 2 — Fetch all groups

The API is called to retrieve all existing tester lists for the app package.

#### Step 3 — Find group by name

The response is searched for a group whose name exactly matches the `group_name` input provided when the workflow was triggered.

#### Step 4 — Create if missing

If no matching group is found, a new tester list is created via the API with the provided name.

#### Step 5 — Add tester

The tester email is added to the group. The tester receives a Play Store opt-in link to join the beta.

### iOS path — step by step

#### Step 1 — Generate JWT

A JSON Web Token is generated using the App Store Connect API key details stored in GitHub Secrets. The token is valid for 20 minutes, which is sufficient for all subsequent API calls.

#### Step 2 — Fetch all beta groups

The App Store Connect API is called to list all beta groups for the app.

#### Step 3 — Find group by name

The response is searched for a group whose name exactly matches the `group_name` input.

#### Step 4 — Create if missing

If no matching group is found, a new external beta group is created via the App Store Connect API. The public link is disabled by default, and feedback is enabled.

#### Step 5 — Create tester record

A beta tester record is created using the tester email, first name, and last name.

#### Step 6 — Add to group

The tester is linked to the group. Apple sends an email invite to the tester automatically.

---

## 4. Group logic — find or create

The `group_name` input is the key that controls everything. The same workflow handles both first-time group setup and all subsequent additions. There is no separate manual step to create a group.

| Scenario | What happens | Result |
|---|---|---|
| Group exists, tester is new | The group is found by name lookup. A tester record is created and linked to the group. | Tester receives an invite. |
| Group does not exist, tester is new | The group is created via the API using the provided name. A tester record is created and linked to the group. | Group and tester are created. Tester receives an invite. |
| Group exists, tester already in group | The group is found. Tester record creation returns a conflict, which the API handles gracefully, so no duplicate is created. | No action needed. Tester already has access. |
| Platform set to both | Android and iOS jobs run in parallel. Each independently checks for or creates its own group with the same name. | Tester is added to both platforms simultaneously. |

### Recommended group naming convention

Use names that include the release version or purpose so groups stay organized over time.

- QA Team v1.2.0 — testers assigned to a specific release
- Client UAT Sprint 14 — user acceptance testing per sprint
- Internal Beta Always On — permanent group for all releases
- Regression v2.0.0 — dedicated regression testing group

Groups are reused automatically. If you run the workflow again with the same `group_name` and a different email, the new tester is added to the existing group without affecting anyone already in it.

---

## 5. What the tester receives

Testers never need to log in to any developer console. They only use the standard Play Store or TestFlight app on their device.

### Android tester experience

- Receives a Play Store opt-in link shared by the team, generated in the Play Console under the tester group.
- Opens the link on an Android device. The Play Store shows the app with a **Join the beta** option.
- After joining, the app appears in the Play Store like a normal install.
- When a new build is uploaded and assigned to the group, the app updates automatically.
- The tester only sees the app. There is no access to the Play Console, crash data, or other apps.

### iOS tester experience

- Receives an email from Apple with a TestFlight invite link.
- Needs a free Apple ID. No Apple Developer account is required.
- Installs the TestFlight app from the App Store, if not already installed.
- In TestFlight, the tester can see and install the specific build assigned to the group.
- When a new build is added to the group and approved, TestFlight notifies testers automatically.
- The tester only sees the app. There is no access to App Store Connect or any other data.

---

## Testing a specific past release

Because all builds are stored as GitHub Actions artifacts for 90 days, any past release can be retrieved and assigned to a tester group at any time:

- Go to GitHub, then **Actions**, and find the workflow run for the past release.
- Download the artifact: AAB for Android, IPA for iOS.
- Upload it manually to the Play Console internal track or App Store Connect TestFlight.
- Assign it to the relevant tester group.
- Testers receive the notification and can install that specific version.

---

## Notification secrets

| Secret name | Used by | Where to get it |
|---|---|---|
| SLACK_WEBHOOK_URL | Both workflows | Create an Incoming Webhook in your Slack workspace under Apps, then Incoming Webhooks. Copy the webhook URL. |

---

## How to base64-encode a file

For certificates and keystores that need to be stored as secrets:

- On macOS or Linux, run: `base64 -i yourfile.p12 \| pbcopy` — this copies the base64 string to your clipboard.
- Paste the result directly into the GitHub secret value field.
- On Windows, run: `certutil -encode yourfile.p12 encoded.txt`, then copy the content of `encoded.txt`.