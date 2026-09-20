import 'dart:io';

import 'package:stepbound/core/core.dart';

void main(List<String> arguments) {
  final seed = arguments.isEmpty ? 20260920 : int.parse(arguments.first);
  final world = createDemoWorld(seed: seed);
  const scheduler = TurnScheduler();
  const renderer = AsciiRenderer();

  stdout
    ..writeln('Deterministic seed: $seed')
    ..write(renderer.render(world));

  while (world.player.isAlive) {
    stdout.write('> ');
    final command = stdin.readLineSync()?.trim().toLowerCase();
    if (command == null || command == 'q') {
      break;
    }
    final action = _actionFor(command);
    if (action == null) {
      stdout.writeln('Unknown command.');
      continue;
    }
    final events = scheduler.advance(world, action);
    for (final event in events) {
      stdout.writeln('- ${event.description}');
    }
    stdout.write(renderer.render(world));
  }

  if (!world.player.isAlive) {
    stdout.writeln('The walk ends here.');
  }
}

PlayerAction? _actionFor(String command) => switch (command) {
  'w' => const MoveAction(Direction.north),
  'd' => const MoveAction(Direction.east),
  's' => const MoveAction(Direction.south),
  'a' => const MoveAction(Direction.west),
  'e' => const InteractAction(),
  'x' || '.' => const WaitAction(),
  _ => null,
};
