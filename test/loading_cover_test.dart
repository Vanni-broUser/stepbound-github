import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/ui/loading_art.dart';

void main() {
  /// How much of the game behind shows through the cover's black.
  double blackOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.byKey(const ValueKey<String>('loading-cover')),
      )
      .opacity
      .value;

  /// How much of the picture shows over the black.
  double pictureOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('loading-cover')),
              matching: find.byType(FadeTransition),
            )
            .last,
      )
      .opacity
      .value;

  testWidgets('fading in from a story, the black hides the game from the '
      'first frame and only the picture fades in; once ready it all fades '
      'out on the game', (tester) async {
    final ready = ValueNotifier<bool>(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingCover(ready: ready, caption: 'Roma', fadeIn: true),
      ),
    );
    expect(blackOpacity(tester), 1, reason: 'no glimpse of the game');
    expect(pictureOpacity(tester), 0);

    await tester.pump(LoadingCover.fadeInDuration);
    expect(blackOpacity(tester), 1);
    expect(pictureOpacity(tester), 1);

    ready.value = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('loading-cover')), findsNothing);
  });

  testWidgets('without the fade in, the picture is there at once', (
    tester,
  ) async {
    final ready = ValueNotifier<bool>(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingCover(ready: ready, caption: 'Roma'),
      ),
    );
    expect(blackOpacity(tester), 1);
    expect(pictureOpacity(tester), 1);
  });
}
