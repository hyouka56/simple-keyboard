package rkr.simplekeyboard.inputmethod.imecheck;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.view.WindowInsets;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.test.InstrumentationTestCase;

public final class KeyboardVisibilityTest extends InstrumentationTestCase {
    private static final String TAG = "KeyboardVisibilityTest";
    private static final long IME_VISIBILITY_TIMEOUT_MS = 10000L;

    public void testKeyboardWindowAppearsForFocusedTextField() throws Exception {
        final Context testContext = getInstrumentation().getContext();
        final Intent intent = new Intent(testContext, KeyboardHostActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        final Activity activity = getInstrumentation().startActivitySync(intent);

        try {
            getInstrumentation().waitForIdleSync();
            final EditText input = ((KeyboardHostActivity) activity).getInput();
            final InputMethodManager imm = (InputMethodManager)
                    activity.getSystemService(Context.INPUT_METHOD_SERVICE);
            assertNotNull("Test text field failed to initialize", input);
            assertNotNull("InputMethodManager is unavailable", imm);

            getInstrumentation().runOnMainSync(() -> {
                input.requestFocus();
                input.post(() -> imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT));
            });

            final long deadline = SystemClock.uptimeMillis() + IME_VISIBILITY_TIMEOUT_MS;
            final boolean[] imeVisible = new boolean[] { false };
            final View decor = activity.getWindow().getDecorView();
            while (SystemClock.uptimeMillis() < deadline) {
                getInstrumentation().waitForIdleSync();
                getInstrumentation().runOnMainSync(() -> {
                    final WindowInsets insets = decor.getRootWindowInsets();
                    imeVisible[0] = insets != null
                            && insets.isVisible(WindowInsets.Type.ime());
                });
                if (imeVisible[0]) {
                    Log.i(TAG, "PASS: selected keyboard IME window is visible for focused EditText");
                    return;
                }
                SystemClock.sleep(200L);
            }

            final String activeIme = Settings.Secure.getString(
                    activity.getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
            Log.e(TAG, "IME window did not become visible; activeIme=" + activeIme
                    + ", inputHasFocus=" + input.hasFocus()
                    + ", activityHasWindowFocus=" + activity.hasWindowFocus());
            fail("The selected keyboard did not show an IME window when a text field was focused.");
        } finally {
            activity.finish();
            getInstrumentation().waitForIdleSync();
        }
    }
}
