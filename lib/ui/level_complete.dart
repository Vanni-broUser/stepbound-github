import 'package:flutter/material.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';

/// The black results screen shown between the last story scene and the
/// Europe map. Memories count distinct story pictures, not dialogue lines.
final class LevelComplete extends StatelessWidget {
  const LevelComplete({
    required this.foundBackpacks,
    required this.totalBackpacks,
    required this.foundMemories,
    required this.totalMemories,
    required this.onContinue,
    super.key,
  });

  final int foundBackpacks;
  final int totalBackpacks;
  final int foundMemories;
  final int totalMemories;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('level-complete'),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit =
              constraints.maxHeight / IntegerResolutionViewport.virtualHeight;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BloodyTitle('LIVELLO COMPLETATO', fontSize: 20 * unit),
                SizedBox(height: 8 * unit),
                MenuPanel(
                  unit: unit,
                  width: MenuButton.fullWidth,
                  child: Column(
                    children: <Widget>[
                      _stat(
                        'ZAINI TROVATI',
                        foundBackpacks,
                        totalBackpacks,
                        unit,
                        const ValueKey<String>('backpack-stat'),
                      ),
                      SizedBox(height: 5 * unit),
                      _stat(
                        'RICORDI TROVATI',
                        foundMemories,
                        totalMemories,
                        unit,
                        const ValueKey<String>('memory-stat'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10 * unit),
                MenuButton(
                  key: const ValueKey<String>('level-complete-continue'),
                  label: 'CONTINUA',
                  unit: unit,
                  onPressed: onContinue,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, int found, int total, double unit, Key key) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: const Color(0xffe8dccb),
              fontFamily: 'monospace',
              fontSize: 8 * unit,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        SizedBox(width: 5 * unit),
        Text(
          '$found / $total',
          style: TextStyle(
            color: BloodColors.bright,
            fontFamily: 'monospace',
            fontSize: 10 * unit,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
