import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/report/telemetry.dart';
import 'package:stepbound/ui/audio_scope.dart';
import 'package:stepbound/ui/main_menu.dart';

/// The settings, the same from the main menu and from the pause menu: the
/// sound, the language, whether error reports and anonymous gameplay data
/// leave the phone on their own (see [Telemetry]), and a way to report a
/// problem by hand, with a message of the player's own; [onBack] apart
/// at the foot. The smaller buttons of the menus over the game, so that
/// all of it fits under the main menu's sign too. The data switch is
/// there only in a build with a server to send to; it starts on.
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
  /// answer), with what the player wrote (maybe nothing): true when it
  /// went to the server, false when it was handed to the share sheet
  /// instead. The button is not there without it.
  final Future<bool> Function(String message)? onReportProblem;

  /// The longest message a player can write.
  static const int maxMessageLength = 1000;

  @override
  State<SettingsChoices> createState() => _SettingsChoicesState();
}

final class _SettingsChoicesState extends State<SettingsChoices> {
  Telemetry get _telemetry => widget.telemetry ?? Telemetry.shared;

  /// Whether the report has gone to the server: the button thanks.
  bool _reported = false;
  bool _reporting = false;

  /// Whether the page to write the report on is open.
  bool _writing = false;
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _write({required bool open}) => setState(() => _writing = open);

  Future<void> _send(Future<bool> Function(String message) report) async {
    if (_reporting) {
      return;
    }
    _reporting = true;
    try {
      final sent = await report(_message.text.trim());
      if (mounted) {
        setState(() {
          _writing = false;
          _reported = sent;
          if (sent) {
            _message.clear();
          }
        });
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
    final report = widget.onReportProblem;
    if (_writing && report != null) {
      return _writePage(report);
    }
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
        if (report != null)
          MenuButton(
            key: const ValueKey<String>('settings-report'),
            label: _reported
                ? strings.reportProblemThanks
                : strings.reportProblem,
            unit: unit,
            compact: true,
            onPressed: _reported ? () {} : () => _write(open: true),
          ),
      ],
    );
  }

  /// What happened, in the player's words: up top, so the keyboard of a
  /// phone in landscape leaves it in view. Sending without writing sends
  /// the report alone.
  Widget _writePage(Future<bool> Function(String message) report) {
    final unit = widget.unit;
    return MenuColumn(
      unit: unit,
      trailing: MenuButton(
        key: const ValueKey<String>('report-back'),
        label: strings.back,
        unit: unit,
        compact: true,
        onPressed: () => _write(open: false),
      ),
      children: <Widget>[
        MenuHeading(text: strings.reportProblem, unit: unit),
        MenuPanel(
          unit: unit,
          width: MenuButton.fullWidth,
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: const ValueKey<String>('report-message'),
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 4,
              maxLength: SettingsChoices.maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              // The keyboard of a phone in landscape hides SEND: its own
              // key closes it, so the button shows again.
              textInputAction: TextInputAction.done,
              cursorColor: const Color(0xffe8dccb),
              style: menuTextStyle(unit, 6.5),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: strings.reportProblemHint,
                hintStyle: menuTextStyle(
                  unit,
                  6.5,
                ).copyWith(color: const Color(0x99e8dccb)),
                counterStyle: menuTextStyle(
                  unit,
                  4.5,
                ).copyWith(color: const Color(0x99e8dccb)),
              ),
            ),
          ),
        ),
        MenuButton(
          key: const ValueKey<String>('report-send'),
          label: strings.reportProblemSend,
          unit: unit,
          compact: true,
          onPressed: () => unawaited(_send(report)),
        ),
      ],
    );
  }
}
