import 'package:flutter/widgets.dart';
import 'package:stepbound/game/audio/game_audio.dart';

/// Hands the app's [GameAudio] to the screens below it, for their taps and
/// the menu's audio switch.
final class AudioScope extends InheritedWidget {
  const AudioScope({required this.audio, required super.child, super.key});

  final GameAudio audio;

  static final GameAudio _silent = SilentAudio();

  /// The audio above [context]; silent when there is none (a screen
  /// pumped on its own in a test). Safe to call from tap handlers.
  static GameAudio of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AudioScope>()?.audio ?? _silent;

  @override
  bool updateShouldNotify(AudioScope oldWidget) => audio != oldWidget.audio;
}
