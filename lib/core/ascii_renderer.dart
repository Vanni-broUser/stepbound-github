import 'package:stepbound/core/entities/components.dart';
import 'package:stepbound/core/entities/entity.dart';
import 'package:stepbound/core/world.dart';

final class AsciiRenderer {
  const AsciiRenderer();

  String render(WorldState world) {
    final rows = world.map.toAsciiRows().map((row) => row.split('')).toList();
    for (final entity in world.entities.values.where(
      (entity) => entity.isAlive,
    )) {
      final position = entity.component<PositionComponent>().position;
      rows[position.y][position.x] = _glyphFor(entity.kind);
    }

    final health = world.player.component<HealthComponent>();
    final buffer = StringBuffer()
      ..writeln('STEPBOUND  tick ${world.tick}')
      ..writeln('health ${health.current}/${health.maximum}')
      ..writeln(rows.map((row) => row.join()).join('\n'))
      ..writeln('WASD move | E interact | X wait | Q quit');
    return buffer.toString();
  }

  String _glyphFor(EntityKind kind) => switch (kind) {
    EntityKind.player => '@',
    EntityKind.wanderer => 'W',
    EntityKind.sprinter => 'S',
    EntityKind.brute => 'B',
    EntityKind.blind => 'C',
    EntityKind.carabiniere => 'K',
    EntityKind.mutilated => 'M',
    EntityKind.burning => 'F',
    EntityKind.drunk => 'U',
    EntityKind.cultist => 'T',
  };
}
