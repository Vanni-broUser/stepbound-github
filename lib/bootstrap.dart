import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/app_services.dart';
import 'package:stepbound/l10n/language_setting.dart';
import 'package:stepbound/report/error_report.dart';
import 'package:stepbound/report/share_report.dart';
import 'package:stepbound/save/vanni_deploy.dart';
import 'package:stepbound/ui/crash_guard.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First of all: an error anywhere below, or later in the game, ends on
  // the error screen with a report to share, instead of in a console
  // nobody reads (lib/report/error_report.dart).
  final reporter = ErrorReporter()..install();
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
  // In the browser, where the game is only tested, it starts silent. The
  // guard over the app owns these from here, through any error, and
  // closes them when the engine lets go.
  final services = AppServices.device(silent: kIsWeb);
  // The words of the game in the language picked last, or the phone's.
  await LanguageSetting().load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final saves = services.saves;
  if (vanniDeployEnabled) {
    try {
      await installVanniDeploySave(saves);
    } on Object catch (error) {
      debugPrint('VANNI_DEPLOY: could not install test save ($error)');
    }
    try {
      await installVanniDeployGifts(saves);
    } on Object catch (error) {
      debugPrint('VANNI_DEPLOY: could not give the test skins ($error)');
    }
  }
  runApp(
    CrashGuard(
      reporter: reporter,
      services: services,
      share: shareReportFile,
      child: StepboundApp(
        services: services,
        skinLinks: skinLinks,
        reporter: reporter,
        share: shareReportFile,
      ),
    ),
  );
}
