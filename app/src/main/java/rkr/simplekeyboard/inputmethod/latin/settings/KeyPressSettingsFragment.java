/*
 * Copyright (C) 2014 The Android Open Source Project
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

import android.content.SharedPreferences;
import android.content.res.Resources;
import android.os.Bundle;

import rkr.simplekeyboard.inputmethod.R;

/** Locked key-press settings; language switching remains available on the preferences screen. */
public final class KeyPressSettingsFragment extends SubScreenFragment {
    @Override
    public void onCreate(final Bundle icicle) {
        super.onCreate(icicle);
        addPreferencesFromResource(R.xml.prefs_screen_key_press);

        // Neutralize values saved by older builds so disabled controls cannot keep sound or popups on.
        final SharedPreferences prefs = getSharedPreferences();
        final Resources res = getResources();
        prefs.edit()
                .putBoolean(Settings.PREF_SOUND_ON, false)
                .putBoolean(Settings.PREF_POPUP_ON, false)
                .putFloat(Settings.PREF_KEYPRESS_SOUND_VOLUME,
                        Settings.readDefaultKeypressSoundVolume())
                .putInt(Settings.PREF_KEY_LONGPRESS_TIMEOUT,
                        Settings.readDefaultKeyLongpressTimeout(res))
                .apply();
    }
}
