/*
 * Copyright (C) 2008 The Android Open Source Project
 * Copyright (C) 2025 Raimondas Rimkus
 * Copyright (C) 2021 wittmane
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package rkr.simplekeyboard.inputmethod.latin.settings;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Resources;
import android.net.Uri;
import android.os.Bundle;
import android.preference.Preference;
import android.preference.PreferenceScreen;
import android.util.Log;

import rkr.simplekeyboard.inputmethod.R;
import rkr.simplekeyboard.inputmethod.latin.utils.ApplicationUtils;

public final class SettingsFragment extends InputMethodSettingsFragment {
    private static final String TAG = "SettingsFragment";

    @Override
    public void onCreate(final Bundle icicle) {
        super.onCreate(icicle);
        setHasOptionsMenu(true);
        addPreferencesFromResource(R.xml.prefs);

        // Keep only language switching configurable; reset legacy values from older builds.
        final SharedPreferences prefs =
                rkr.simplekeyboard.inputmethod.compat.PreferenceManagerCompat
                        .getDeviceSharedPreferences(getActivity());
        prefs.edit()
                .putBoolean(Settings.PREF_AUTO_CAP, false)
                .putBoolean(Settings.PREF_SHOW_NUMBER_ROW, false)
                .putBoolean(Settings.PREF_SHOW_SPECIAL_CHARS, false)
                .putBoolean(Settings.PREF_USE_ON_SCREEN, false)
                .putBoolean(Settings.PREF_ENABLE_IME_SWITCH, false)
                .putBoolean(Settings.PREF_SPACE_SWIPE, false)
                .putBoolean(Settings.PREF_DELETE_SWIPE, false)
                .putBoolean(Settings.PREF_SOUND_ON, false)
                .putBoolean(Settings.PREF_POPUP_ON, false)
                .putFloat(Settings.PREF_KEYPRESS_SOUND_VOLUME,
                        Settings.readDefaultKeypressSoundVolume())
                .putInt(Settings.PREF_KEY_LONGPRESS_TIMEOUT,
                        Settings.readDefaultKeyLongpressTimeout(getResources()))
                .apply();

        final PreferenceScreen preferenceScreen = getPreferenceScreen();
        if (preferenceScreen != null) {
            preferenceScreen.setTitle(
                    ApplicationUtils.getActivityTitleResId(getActivity(), SettingsActivity.class));
        }
        final Resources res = getResources();

        final Preference privacyPreference = findPreference("privacy_policy");
        if (privacyPreference != null) {
            privacyPreference.setOnPreferenceClickListener(new Preference.OnPreferenceClickListener() {
                @Override
                public boolean onPreferenceClick(Preference preference) {
                    openUrl(res.getString(R.string.privacy_policy_url));
                    return true;
                }
            });
        }
        final Preference licensePreference = findPreference("license");
        if (licensePreference != null) {
            licensePreference.setOnPreferenceClickListener(new Preference.OnPreferenceClickListener() {
                @Override
                public boolean onPreferenceClick(Preference preference) {
                    openUrl(res.getString(R.string.license_url));
                    return true;
                }
            });
        }
    }

    private void openUrl(String uri) {
        try {
            final Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(uri));
            startActivity(browserIntent);
        } catch (ActivityNotFoundException e) {
            Log.e(TAG, "Browser not found");
        }
    }
}
