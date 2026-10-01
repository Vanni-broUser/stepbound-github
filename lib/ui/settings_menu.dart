import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/main_menu.dart';

/// The settings, the same from the main menu and from the pause menu: the
/// sound, the language, whether error reports and anonymous gameplay data
/// leave the phone on their own (see [Telemetry]), and a way to report a
/// problem by hand; [onBack] apart at the foot. The smaller buttons of
/// the menus over the game, so that all of it fits under the main menu's
/// sign too. The data switch is there
/// only in a build with a server to send to; it starts on.
final class SettingsChoices extends StatefulWidget {
  const SettingsChoices({
    required this.unit,
    required this.onBack,
    this.telemetry,
    this.onReportProblem,
    super.key,
  });

  final double unit;
  final VoidCallback onBack;

  /// Whose switch it is; the app's own when null.
  final Telemetry? telemetry;

  /// Sends a report with no error in it, for the bugs that throw nothing
  /// (a script that never lets go of Mario, a button that does not
  /// answer): true when it went to the server, false when it was handed
  /// to the share sheet instead. The button is not there without it.
  final Future<bool> Function()? onReportProblem;

  @override
  State<SettingsChoices> createState() => _SettingsChoicesState();
}

final class _SettingsChoicesState extends State<SettingsChoices> {
  Telemetry get _telemetry => widget.telemetry ?? Telemetry.shared;

  /// Whether the report has gone to the server: the button thanks.
  bool _reported = false;
  bool _reporting = false;

  Future<void> _report(Future<bool> Function() report) async {
    if (_reporting || _reported) {
      return;
    }
    _reporting = true;
    try {
      final sent = await report();
      if (sent && mounted) {
        setState(() => _reported = true);
      }
    } finally {
      _reporting = false;
    }
  }

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
        if (widget.onReportProblem case final report?)
          MenuButton(
            key: const ValueKey<String>('settings-report'),
            label: _reported
                ? strings.reportProblemThanks
                : strings.reportProblem,
            unit: unit,
            compact: true,
            onPressed: () => unawaited(_report(report)),
          ),
      ],
    );
  }
}
