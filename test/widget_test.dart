import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';

void main() {
  testWidgets('F0 renders the intentionally blank surface', (tester) async {
    await tester.pumpWidget(const StepboundApp(flavor: AppFlavor.dev));

    expect(
      find.byKey(const ValueKey<String>('stepbound-empty-surface')),
      findsOneWidget,
    );
    expect(find.text('Stepbound'), findsNothing);
  });
}
