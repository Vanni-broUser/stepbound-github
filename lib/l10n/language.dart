import 'package:flutter/foundation.dart';
import 'package:stepbound/l10n/en.dart';
import 'package:stepbound/l10n/it.dart';
import 'package:stepbound/l10n/strings.dart';

export 'package:stepbound/l10n/strings.dart';

/// The languages the game speaks. Only its words change with it: the
/// signs, the shop names and everything else painted on the maps stay
/// Italian, because the game is set in Italy.
///
/// Adding one takes a copy of en.dart translated (its class implements
/// [Strings], so the compiler names every line still missing) and a value
/// here: see docs/lingue.md.
enum Language {
  italian(code: 'it', nativeName: 'ITALIANO', strings: ItalianStrings()),
  english(code: 'en', nativeName: 'ENGLISH', strings: EnglishStrings());

  const Language({
    required this.code,
    required this.nativeName,
    required this.strings,
  });

  /// Its ISO 639-1 code, as a phone's locale names it: shown on the main
  /// menu's switch and kept in the preferences.
  final String code;

  /// Its own name for itself, as its speakers look for it.
  final String nativeName;

  final Strings strings;

  /// The language of a phone that speaks none of these: the original.
  static const Language fallback = italian;

  /// The one the game speaks now. Italian until the app reads the
  /// player's choice (see `LanguageSetting`), so tests read the original.
  static final ValueNotifier<Language> current = ValueNotifier<Language>(
    italian,
  );

  /// The language whose [code] is [code] (only the language of a locale:
  /// `en` of `en_GB`), or null when the game does not speak it.
  static Language? byCode(String? code) {
    for (final language in values) {
      if (language.code == code?.toLowerCase()) {
        return language;
      }
    }
    return null;
  }

  /// The one after this in the main menu's switch, back to the first after
  /// the last.
  Language get next => values[(index + 1) % values.length];
}

/// Every word of the game in the language it speaks now.
Strings get strings => Language.current.value.strings;

/// Place names as [Strings.placeNames] translates them.
extension PlaceNames on Strings {
  /// [name] as a place is called in this language: the names the maps
  /// give places are Italian, and those that are proper names (Piazza dei
  /// Cinquecento) stay so.
  String place(String name) => placeNames[name] ?? name;
}
