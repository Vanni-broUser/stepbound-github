import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/main_menu.dart';

/// The settings, the same from the main menu and from the pause menu: the
/// sound, the language, and whether error reports and anonymous gameplay
/// data leave the phone on their own (see [Telemetry]); [onBack] apart at
/// the foot. The smaller buttons of the menus over the game, so that all
/// of it fits under the main menu's sign too. The data switch is there
/// only in a build with a server to send to; it starts on.
final class SettingsChoices extends StatefulWidget {
  const SettingsChoices({
    required this.unit,
    required this.onBack,
    this.telemetry,
    super.key,
  });

  final double unit;
  final VoidCallback onBack;

  /// Whose switch it is; the app's own when null.
  final Telemetry? telemetry;

  @override
  State<SettingsChoices> createState() => _SettingsChoicesState();
}

final class _SettingsChoicesState extends State<SettingsChoices> {
  Telemetry get _telemetry => widget.telemetry ?? Telemetry.shared;

  void _toggleAudio() {
    final audio = AudioScope.of(context);
    setState(() => audio.muted = !audio.muted);
  }

  /// Every word on the screen changes at once: the app rebuilds with the
  /// language (see `StepboundApp`), these settings included.
  void _nextLanguage() => Language.current.value = Language.current.value.next;

  void _toggleData() {
    unawaited(_telemetry.setEnabled(enabled: !_telemetry.enabled));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    return MenuColumn(
      unit: unit,
      trailing: MenuButton(
        key: const ValueKey<String>('settings-back'),
        label: strings.back,
        unit: unit,
        compact: true,
        onPressed: widget.onBack,
      ),
      children: <Widget>[
        MenuHeading(text: strings.settingsTitle, unit: unit),
        MenuButton(
          key: const ValueKey<String>('settings-audio'),
          label: AudioScope.of(context).muted
              ? strings.menuAudioOff
              : strings.menuAudioOn,
          unit: unit,
          compact: true,
          onPressed: _toggleAudio,
        ),
        MenuButton(
          key: const ValueKey<String>('settings-language'),
          label: strings.settingsLanguage(Language.current.value.nativeName),
          unit: unit,
          compact: true,
          onPressed: _nextLanguage,
        ),
        if (_telemetry.available)
          MenuButton(
            key: const ValueKey<String>('settings-send-data'),
            label: strings.settingsSendData(on: _telemetry.enabled),
            unit: unit,
            compact: true,
            onPressed: _toggleData,
          ),
      ],
    );
  }
}
