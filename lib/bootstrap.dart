import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/game/audio/player_audio.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/vanni_deploy.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final saves = PreferencesSaveRepository();
  if (vanniDeployEnabled) {
    try {
      await installVanniDeploySave(saves);
    } on Object catch (error) {
      debugPrint('VANNI_DEPLOY: could not install test save ($error)');
    }
  }
  // In the browser, where the game is only tested, it starts silent.
  runApp(
    StepboundApp(
      saves: saves,
      audio: PlayerAudio(startMuted: kIsWeb),
    ),
  );
}
