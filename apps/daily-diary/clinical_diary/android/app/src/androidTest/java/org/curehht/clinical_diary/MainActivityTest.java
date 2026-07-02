package org.curehht.clinical_diary;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Native Android bridge used by Flutter integration_test and Firebase Test Lab.
 * The Dart tests are selected at Gradle build time with -Ptarget=<test file>.
 */
// Verifies: DIARY-OPS-build-deploy-primitives/A+B
// Verifies: DIARY-OPS-single-promotable-artifact/C
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
    @Rule
    public ActivityTestRule<MainActivity> rule =
            new ActivityTestRule<>(MainActivity.class, true, false);
}
