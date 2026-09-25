import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/game/audio/player_audio.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(StepboundApp(audio: PlayerAudio()));
}
