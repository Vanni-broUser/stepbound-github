import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/game/zombie_lore.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  group('zombie discovery', () {
    List<Entity> mutilated() => world.entities.values
        .where((entity) => entity.kind == EntityKind.mutilated)
        .toList();

    GridPoint at(Entity zombie) =>
        zombie.component<PositionComponent>().position;

    test('the first mutilated in sight is introduced with its '
        'portrait and entered in the book', () {
      final zombies = mutilated();
      expect(zombies, isNotEmpty);
      settle();
      expect(host.shown, isEmpty, reason: 'none is on screen yet');
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));

      host.visible.add(at(zombies.first));
      director.update(0.1, turnAnimating: false);
      expect(host.wholeViews, 1);
      expect(progress.knownZombies, contains(EntityKind.mutilated));
      expect(host.shown, hasLength(1), reason: 'straight away, no pan first');
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.mutilated]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.mutilated]!.portrait);
      expect(line.speaker, isNull);
      host.dismiss();

      // The others in sight later say nothing more.
      host.visible.addAll(zombies.map(at));
      settle();
      expect(host.shown, hasLength(1), reason: 'the lesson is given once');
    });

    test('the burning zombie on the roofs is introduced when first seen', () {
      final zombie = world.entities[rooftopBurningZombieId]!;
      host.visible.add(at(zombie));
      settle();
      expect(host.wholeViews, 1);
      expect(progress.knownZombies, contains(EntityKind.burning));
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.burning]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.burning]!.portrait);
    });

    test('the drunk in the Bar Arcobaleno is introduced when first seen', () {
      final zombie = world.entities[barDrunkZombieId]!;
      expect(zombie.kind, EntityKind.drunk);
      expect(place(PlaceId.barArcobaleno).bounds.contains(at(zombie)), isTrue);
      host.visible.add(at(zombie));
      settle();
      expect(host.wholeViews, 1);
      expect(progress.knownZombies, contains(EntityKind.drunk));
      final line = host.shown.single.single;
      expect(line.text, zombieLore[EntityKind.drunk]!.lesson);
      expect(line.portrait, zombieLore[EntityKind.drunk]!.portrait);
    });

    test('a dead one is no introduction', () {
      final zombie = mutilated().first;
      zombie.component<HealthComponent>().current = 0;
      host.visible.add(at(zombie));
      settle();
      expect(host.shown, isEmpty);
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));
    });

    test('a type met before, in this level or another, is not introduced '
        'again', () {
      final known = StoryDirector(
        world: world,
        host: host,
        progress: Progress(knownZombies: <EntityKind>[EntityKind.mutilated]),
      );
      host.visible.add(at(mutilated().first));
      for (var i = 0; i < 20; i++) {
        known.update(0.1, turnAnimating: false);
      }
      expect(host.shown, isEmpty);
      expect(host.wholeViews, 0);
    });

    test('it survives a save through the progress, not the story scripts', () {
      host.visible.add(at(mutilated().first));
      settle();
      host.dismiss();
      final restored = StoryDirector(
        world: world,
        host: host,
        progress: Progress.fromJson(progress.toJson()),
      )..restore(director.toJson());
      for (var i = 0; i < 20; i++) {
        restored.update(0.1, turnAnimating: false);
      }
      expect(host.shown, hasLength(1));
    });

    test('two new types in sight at once are introduced one after the '
        'other', () {
      final sprinter = world.entities.values.firstWhere(
        (entity) => entity.kind == EntityKind.sprinter,
      );
      final zombie = mutilated().first;
      host.visible
        ..add(at(sprinter))
        ..add(at(zombie));
      settle();
      expect(host.shown, hasLength(1));
      host.dismiss();
      settle();
      expect(host.shown, hasLength(2));
      expect(
        <String>{for (final lines in host.shown) lines.single.text},
        <String>{
          zombieLore[EntityKind.sprinter]!.lesson,
          zombieLore[EntityKind.mutilated]!.lesson,
        },
      );
    });

    test('a new type waits for what is being said to be over', () {
      host.showPrompt(const <StoryLine>[StoryLine('...')]);
      host.visible.add(at(mutilated().first));
      settle();
      expect(host.wholeViews, 0, reason: 'nothing to show yet');
      expect(progress.knownZombies, isNot(contains(EntityKind.mutilated)));
      host.dismiss();
      settle();
      expect(
        host.shown.last.single.text,
        zombieLore[EntityKind.mutilated]!.lesson,
      );
    });

    test('every zombie type the game places has its lore', () {
      final kinds = <EntityKind>{
        for (final entity in world.entities.values)
          if (entity.kind != EntityKind.player) entity.kind,
        // The barracks' carabinieri come out of the dark later.
        EntityKind.carabiniere,
      };
      for (final kind in kinds) {
        final lore = zombieLore[kind];
        expect(lore, isNotNull, reason: '$kind has no lore');
        expect(lore!.lesson, isNotEmpty, reason: '$kind');
        expect(lore.description, isNotEmpty, reason: '$kind');
        expect(
          lore.portrait,
          startsWith('assets/characters/zombies/portraits/'),
        );
      }
    });
  });
}
