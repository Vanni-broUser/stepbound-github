import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/main_menu.dart';

/// Over the game, when a save at a campfire or at the train's table could
/// not be written: the line saying so, and the same two ways out as the
/// error screen, the report to share or on with the game.
final class SaveFailedNotice extends StatelessWidget {
  const SaveFailedNotice({
    required this.line,
    required this.onShare,
    required this.onContinue,
    super.key,
  });

  /// What went wrong and how to try again.
  final String line;
  final VoidCallback onShare;
  final VoidCallback onContinue;

  static String get shareLabel => strings.shareReport;
  static String get continueLabel => strings.continueLabel;

  @override
  Widget build(BuildContext context) {
    return Letterbox(
      color: Letterbox.veil,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit = constraints.maxHeight.isFinite
              ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
              : 1.0;
          return Padding(
            key: const ValueKey<String>('save-failed-notice'),
            padding: EdgeInsets.all(8 * unit),
            child: Center(
              child: SingleChildScrollView(
                child: MenuColumn(
                  unit: unit,
                  children: <Widget>[
                    MenuPanel(
                      unit: unit,
                      width: MenuButton.fullWidth,
                      opaque: true,
                      child: MenuParagraph(
                        line,
                        key: const ValueKey<String>('save-failed-line'),
                        unit: unit,
                        center: true,
                      ),
                    ),
                    MenuButton(
                      key: const ValueKey<String>('save-failed-share'),
                      label: shareLabel,
                      unit: unit,
                      compact: true,
                      onPressed: onShare,
                    ),
                    MenuButton(
                      key: const ValueKey<String>('save-failed-continue'),
                      label: continueLabel,
                      unit: unit,
                      compact: true,
                      onPressed: onContinue,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
