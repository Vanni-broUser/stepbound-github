import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the report to the system's share sheet as a text file, for the
/// player to send by whatever they use. In the browser, where files cannot
/// be shared, the text itself goes.
Future<void> shareReportFile(String fileName, String text) async {
  const subject = 'Rapporto di errore di Stepbound';
  if (kIsWeb) {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    return;
  }
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
  );
  await file.writeAsString(text, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: subject,
      text: subject,
    ),
  );
}
