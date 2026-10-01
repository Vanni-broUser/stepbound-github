import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/l10n/language.dart';
import 'package:stepbound/ui/letterbox.dart';
import 'package:stepbound/ui/loading_art.dart';
import 'package:stepbound/ui/main_menu.dart';

/// What the player sees when the game stops on an error nobody caught:
/// what happened in a line, what the report holds, and two ways out. All
/// of it fits the 16:9 picture: the words on the left, the choices on the
/// right, nothing to scroll for, over the loading picture rather than on
/// black.
final class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    required this.summary,
    required this.onShare,
    required this.onMenu,
    this.sharing = false,
    this.sentOnItsOwn = false,
    super.key,
  });

  /// The error's first line.
  final String summary;
  final VoidCallback onShare;
  final VoidCallback onMenu;

  /// While the share sheet is being prepared: the button waits.
  final bool sharing;

  /// Whether the report leaves the phone by itself (see `Telemetry`): the
  /// screen then says so, and sharing it is only for whoever wants to.
  final bool sentOnItsOwn;

  static String get title => strings.errorTitle;
  static String get explanation => strings.errorExplanation;
  static String get explanationSent => strings.errorExplanationSent;
  static String get shareLabel => strings.shareReport;
  static String get sharingLabel => strings.errorSharing;
  static String get menuLabel => strings.errorBackToMenu;

  /// The buttons' width, in virtual pixels.
  static const double buttonWidth = 120;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const LoadingBackdrop(),
        Letterbox(
          color: const Color(0x00000000),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit = constraints.maxHeight.isFinite
                  ? constraints.maxHeight /
                        IntegerResolutionViewport.virtualHeight
                  : 1.0;
              return Padding(
                key: const ValueKey<String>('error-screen'),
                padding: EdgeInsets.all(8 * unit),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    MenuHeading(text: title, unit: unit),
                    SizedBox(height: 4 * unit),
                    // As tall as the words, no taller; a summary too long for
                    // the picture scrolls inside the panel.
                    Flexible(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: MenuPanel(
                              unit: unit,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    MenuParagraph(
                                      sentOnItsOwn
                                          ? explanationSent
                                          : explanation,
                                      unit: unit,
                                    ),
                                    SizedBox(height: 4 * unit),
                                    MenuParagraph(
                                      summary,
                                      key: const ValueKey<String>(
                                        'error-summary',
                                      ),
                                      unit: unit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6 * unit),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              MenuButton(
                                key: const ValueKey<String>('error-share'),
                                label: sharing ? sharingLabel : shareLabel,
                                unit: unit,
                                width: buttonWidth,
                                compact: true,
                                onPressed: sharing ? () {} : onShare,
                              ),
                              SizedBox(height: MenuColumn.gap * unit),
                              MenuButton(
                                key: const ValueKey<String>('error-menu'),
                                label: menuLabel,
                                unit: unit,
                                width: buttonWidth,
                                compact: true,
                                onPressed: onMenu,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
