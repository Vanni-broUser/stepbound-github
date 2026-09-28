import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the phone and the installed build are, for the head of an error
/// report. Android answers over [channel] (`MainActivity.kt`); anywhere
/// else, or when the channel is missing (tests, the browser), the fields
/// say so instead of failing: a report must always come out.
final class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.system,
    required this.memory,
    required this.appVersion,
  });

  /// Maker and model, e.g. `Xiaomi Redmi 9`.
  final String model;

  /// Operating system and its version.
  final String system;

  /// Free and total memory, as the system reports them.
  final String memory;

  /// `versionName (versionCode)` of the installed package: the code is the
  /// pipeline number the build came from.
  final String appVersion;

  static const String unknown = 'sconosciuto';

  static const MethodChannel channel = MethodChannel('stepbound/device');

  static Future<DeviceInfo> read() async {
    try {
      final info = await channel.invokeMapMethod<String, Object?>('info');
      if (info != null) {
        return DeviceInfo(
          model: '${info['manufacturer'] ?? ''} ${info['model'] ?? ''}'.trim(),
          system: '${info['system'] ?? unknown}',
          memory: '${info['memory'] ?? unknown}',
          appVersion:
              '${info['versionName'] ?? unknown} '
              '(${info['versionCode'] ?? '?'})',
        );
      }
    } on MissingPluginException {
      // Not Android, or no engine: the fallback below.
    } on PlatformException {
      // The activity could not answer: the fallback below.
    }
    return DeviceInfo(
      model: unknown,
      system: kIsWeb ? 'web' : defaultTargetPlatform.name,
      memory: unknown,
      appVersion: unknown,
    );
  }
}
