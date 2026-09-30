import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepbound/l10n/language.dart';

/// The player's language, kept in the preferences: the one picked on the
/// main menu, or the phone's own until one is picked.
final class LanguageSetting {
  LanguageSetting({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String key = 'stepbound.language';

  final SharedPreferencesAsync _preferences;

  /// Sets [Language.current] to the language picked last, or else to the
  /// language of [device] when the game speaks it, or else to
  /// [Language.fallback]; from then on every change is kept.
  Future<void> load(Locale device) async {
    String? picked;
    try {
      picked = await _preferences.getString(key);
    } on Object catch (error) {
      debugPrint('language: could not read the setting ($error)');
    }
    Language.current.value =
        Language.byCode(picked) ??
        Language.byCode(device.languageCode) ??
        Language.fallback;
    Language.current.addListener(_keep);
  }

  /// Stops keeping the changes.
  void dispose() => Language.current.removeListener(_keep);

  void _keep() => unawaited(_write(Language.current.value));

  Future<void> _write(Language language) async {
    try {
      await _preferences.setString(key, language.code);
    } on Object catch (error) {
      debugPrint('language: could not keep ${language.code} ($error)');
    }
  }
}
