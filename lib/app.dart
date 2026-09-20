import 'package:flutter/material.dart';

enum AppFlavor { dev, prod }

final class StepboundApp extends StatelessWidget {
  const StepboundApp({required this.flavor, super.key});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stepbound',
      debugShowCheckedModeBanner: flavor == AppFlavor.dev,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0b0d0e),
      ),
      home: const ColoredBox(
        key: ValueKey<String>('stepbound-empty-surface'),
        color: Color(0xff0b0d0e),
      ),
    );
  }
}
