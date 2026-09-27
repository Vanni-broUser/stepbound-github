import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/game/audio/player_audio.dart';
import 'package:stepbound/save/outfit_unlocks.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/save/vanni_deploy.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Instantiate the listener before startup work so a cold-start link cannot
  // be missed while orientation and system UI are being configured.
  final skinLinks = AppLinks().uriLinkStream;
  // On Android the manifest's sensorLandscape already locks to landscape and
  // flips between both sides with the sensor. Asking Flutter for the same two
  // orientations would replace it with userLandscape, which obeys the system
  // rotation lock and keeps the game upside down when the phone is turned.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final saves = PreferencesSaveRepository();
  final outfitUnlocks = PreferencesOutfitUnlockRepository();
  if (vanniDeployEnabled) {
    try {
      await installVanniDeploySave(saves);
    } on Object catch (error) {
      debugPrint('VANNI_DEPLOY: could not install test save ($error)');
    }
    try {
      await installVanniDeployOutfits(outfitUnlocks);
    } on Object catch (error) {
      debugPrint('VANNI_DEPLOY: could not unlock test outfits ($error)');
    }
  }
  // In the browser, where the game is only tested, it starts silent.
  runApp(
    StepboundApp(
      saves: saves,
      audio: PlayerAudio(startMuted: kIsWeb),
      outfitUnlocks: outfitUnlocks,
      skinLinks: skinLinks,
    ),
  );
}
