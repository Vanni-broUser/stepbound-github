import 'dart:io';
import 'dart:math';

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/app.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/game_audio.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/audio/soundscape.dart';
import 'package:stepbound/game/levels/rome_stage.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/stepbound_game.dart';
import 'package:stepbound/save/save_game.dart';
import 'package:stepbound/ui/zombie_book.dart';

import 'test_world.dart';

/// A long corridor: Mario on the left, a zombie [zombieAt] tiles away.
WorldState _corridor({int zombieAt = 4}) {
  final factory = EntityFactory(BalanceConfig.standard());
  const width = 40;
  return WorldState(
    map: TileMap.fromAscii(<String>[
      '#' * width,
      '#${'.' * (width - 2)}#',
      '#' * width,
    ]),
    entities: <Entity>[
      factory.player(id: 'player', position: const GridPoint(1, 1)),
      factory.zombie(
        id: 'zombie',
        kind: EntityKind.wanderer,
        position: GridPoint(1 + zombieAt, 1),
      ),
    ],
    playerId: 'player',
    random: SeededRandom(7),
  );
}

void _hunt(WorldState world) =>
    world.entities['zombie']!.component<HearingComponent>().lastHeard =
        const GridPoint(1, 1);

void main() {
  test('Rome has its own music, in the station and the streets alike', () {
    final stage = RomeStage(
      StepboundGame(world: createGameWorld(), progress: Progress()),
    );
    for (final place in gamePlaces) {
      expect(
        stage.musicOf(place.id),
        place.level == LevelId.rome ? Music.rome : isNull,
        reason: '${place.id}',
      );
    }
  });

  test('the company plays the hold music gone wrong, its street not', () {
    final stage = StepboundGame(
      world: createGameWorld(),
      progress: Progress(),
    ).hometown;
    const company = <PlaceId>{
      PlaceId.companyGround,
      PlaceId.companyFirst,
      PlaceId.companySecond,
    };
    for (final id in company) {
      expect(stage.musicOf(id), Music.weasel, reason: '$id');
    }
    expect(stage.musicOf(PlaceId.industryStreet), isNull);
    expect(stage.musicOf(PlaceId.monumentSquare), isNull);
  });

  test('once met, Tonino and Marcello bring their music into view', () {
    final progress = Progress();
    final game = StepboundGame(world: createGameWorld(), progress: progress)
      ..onGameResize(Vector2(768, 432));
    final stage = RomeStage(game);
    void lookAt(GridPoint tile) =>
        game.camera.viewfinder.position = Vector2(tile.x * 16.0, tile.y * 16);
    final far = GridPoint(marcelloTile.x, marcelloTile.y - 60);

    lookAt(marcelloTile);
    expect(
      stage.musicOf(PlaceId.piazzaCinquecento),
      Music.rome,
      reason: 'strangers still',
    );

    progress.view(StoryMemory.maranzaMet);
    expect(stage.musicOf(PlaceId.piazzaCinquecento), Music.maranza);
    lookAt(far);
    expect(stage.musicOf(PlaceId.piazzaCinquecento), Music.rome);
  });

  test('their meeting and its memory play their music', () {
    expect(
      memoryScenes[StoryMemory.maranzaMet]!.map((scene) => scene.music),
      everyElement(Music.maranza),
    );
    expect(File('assets/audio/${Music.maranza.file}').existsSync(), isTrue);
  });

  group('Soundscape', () {
    test('plays the street outdoors and the barracks theme indoors', () {
      final soundscape = Soundscape(world: _corridor(), fires: const []);
      expect(soundscape.update(0.1, indoor: false).music, Music.street);
      final inside = soundscape.update(0.1, indoor: true);
      expect(inside.music, Music.barracks);
      expect(inside.ambience[Ambience.indoor], greaterThan(0));
      expect(inside.ambience[Ambience.wind], 0);
    });

    test('a zombie hunting close by turns the music, which lingers', () {
      final world = _corridor();
      final soundscape = Soundscape(world: world, fires: const []);
      expect(soundscape.update(0.1, indoor: false).music, Music.street);

      _hunt(world);
      expect(soundscape.update(0.1, indoor: false).music, Music.danger);

      world.entities['zombie']!.component<HealthComponent>().current = 0;
      expect(soundscape.update(1, indoor: false).music, Music.danger);
      expect(
        soundscape.update(Soundscape.dangerHoldSeconds, indoor: false).music,
        Music.street,
      );
    });

    test("a place's own music replaces the street's and the indoor one, "
        'a chase still drowns it, a story scene drowns everything', () {
      final world = _corridor();
      final soundscape = Soundscape(world: world, fires: const []);
      expect(
        soundscape.update(0.1, indoor: true, theme: Music.sacred).music,
        Music.sacred,
      );
      _hunt(world);
      expect(
        soundscape.update(0.1, indoor: true, theme: Music.sacred).music,
        Music.danger,
      );
      final scene = soundscape.update(
        0.1,
        indoor: true,
        theme: Music.sacred,
        scene: Music.luigi,
      );
      expect(scene.music, Music.luigi);
      expect(scene.musicLevel, 1);
    });

    test('ground on fire crackles like any fire, louder closer to it', () {
      final world = _corridor(zombieAt: 30);
      final soundscape = Soundscape(world: world, fires: const []);
      expect(soundscape.update(0.1, indoor: false).ambience[Ambience.fire], 0);

      world.map.setTile(const GridPoint(5, 1), const Tile(TileKind.fire));
      final far = soundscape
          .update(0.1, indoor: false)
          .ambience[Ambience.fire]!;
      expect(far, greaterThan(0));
      world.map.setTile(const GridPoint(2, 1), const Tile(TileKind.fire));
      final near = soundscape.update(0.1, indoor: false);
      expect(near.ambience[Ambience.fire], greaterThan(far));
      expect(near.musicLevel, lessThan(1), reason: 'it pushes the music back');
      expect(
        soundscape.update(0.1, indoor: true).ambience[Ambience.fire],
        0,
        reason: 'not heard indoors',
      );
    });

    test('a hunting zombie far away is no danger yet', () {
      final world = _corridor(zombieAt: Soundscape.dangerRadius + 5);
      _hunt(world);
      final soundscape = Soundscape(world: world, fires: const []);
      expect(soundscape.update(0.1, indoor: false).music, Music.street);
    });

    test('a campfire crackles and pushes the music back', () {
      final soundscape = Soundscape(
        world: _corridor(zombieAt: 30),
        fires: const <FireSpot>[FireSpot(GridPoint(2, 1), FireKind.campfire)],
      );
      final mix = soundscape.update(0.1, indoor: false);
      expect(mix.ambience[Ambience.fire], greaterThan(0.5));
      expect(mix.musicLevel, lessThan(1));
      expect(
        soundscape.update(0.1, indoor: false, resting: true).musicLevel,
        lessThan(mix.musicLevel),
      );
    });

    test('after death only the wind is left', () {
      final soundscape = Soundscape(world: _corridor(), fires: const []);
      final mix = soundscape.update(0.1, indoor: false, gameOver: true);
      expect(mix.music, isNull);
      expect(mix.ambience[Ambience.fire], 0);
    });

    test('turns events into effects, quieter far from Mario', () {
      final soundscape = Soundscape(
        world: _corridor(zombieAt: 8),
        fires: const [],
      );
      final cues = soundscape.soundsFor(const <WorldEvent>[
        MovedEvent(
          entityId: 'player',
          from: GridPoint(0, 1),
          to: GridPoint(1, 1),
        ),
        ShotEvent(
          entityId: 'player',
          origin: GridPoint(1, 1),
          impact: GridPoint(9, 1),
          direction: Direction.east,
          hitEntityId: 'zombie',
        ),
        AlertedEvent(entityId: 'zombie', at: GridPoint(9, 1)),
        DiedEvent('zombie'),
      ]);
      expect(
        <Sfx>[for (final cue in cues) cue.sfx],
        <Sfx>[
          Sfx.step,
          Sfx.gunshot,
          Sfx.hitFlesh,
          Sfx.zombieAlert,
          Sfx.zombieDeath,
        ],
      );
      final alert = cues.firstWhere((cue) => cue.sfx == Sfx.zombieAlert);
      expect(alert.volume, lessThan(1));
      expect(cues.first.volume, 1);
    });

    test('a door creaks; the grappling hook whips, catches and creaks', () {
      final soundscape = Soundscape(world: _corridor(), fires: const []);
      Sfx? of({required bool grappled}) => soundscape
          .soundsFor(<WorldEvent>[
            TeleportedEvent(
              entityId: 'player',
              from: const GridPoint(1, 1),
              to: const GridPoint(4, 1),
              grappled: grappled,
            ),
          ])
          .single
          .sfx;
      expect(of(grappled: false), Sfx.door);
      expect(of(grappled: true), Sfx.grapple);
    });

    test('a bite on Mario sounds, a zombie out of earshot does not', () {
      final soundscape = Soundscape(
        world: _corridor(zombieAt: Soundscape.hearingRadius.toInt() + 2),
        fires: const [],
      );
      final cues = soundscape.soundsFor(const <WorldEvent>[
        DamagedEvent(entityId: 'player', amount: 1, sourceEntityId: 'zombie'),
        AlertedEvent(entityId: 'zombie', at: GridPoint(20, 1)),
      ]);
      expect(
        <Sfx>[for (final cue in cues) cue.sfx],
        <Sfx>[Sfx.zombieBite, Sfx.playerHurt],
      );
    });

    test('idle zombies groan only now and then', () {
      final soundscape = Soundscape(
        world: corridorWorld(EntityKind.wanderer),
        fires: const [],
        random: Random(3),
      );
      var moans = 0;
      for (var turn = 0; turn < 500; turn++) {
        moans += soundscape.idleMoans().length;
      }
      expect(moans, inInclusiveRange(5, 45));
    });
  });

  test('every sound the game names is in the assets', () {
    final files = <String>[
      for (final music in Music.values) music.file,
      for (final ambience in Ambience.values) ambience.file,
      for (final sfx in Sfx.values) ...sfx.files,
    ];
    for (final file in files) {
      expect(File('assets/audio/$file').existsSync(), isTrue, reason: file);
    }
  });

  group('app', () {
    testWidgets('the menu has its music, the story its own', (tester) async {
      final audio = SilentAudio();
      final saves = MemorySaveRepository();
      await tester.pumpWidget(StepboundApp(saves: saves, audio: audio));
      await tester.pump();
      expect(audio.music, Music.menu);

      await tester.tap(find.byKey(const ValueKey<String>('menu-new-game')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-slot-1')));
      await tester.pump();
      expect(audio.music, Music.story);
      expect(audio.played, contains(Sfx.uiClick));
    });

    testWidgets('putting the app down silences it, at every step of the '
        'way out and back', (tester) async {
      final audio = SilentAudio();
      await tester.pumpWidget(
        StepboundApp(saves: MemorySaveRepository(), audio: audio),
      );
      await tester.pump();
      expect(audio.paused, isFalse);

      void go(AppLifecycleState state) =>
          tester.binding.handleAppLifecycleStateChanged(state);

      // The way out: a call or the app switcher stops at inactive, the
      // background carries on through hidden to paused. The sound has to
      // be off from the first step, or the game over sting plays on.
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        go(state);
        expect(audio.paused, isTrue, reason: r'silent at $state');
      }
      // And the way back in, sound only once it is in front again.
      for (final state in <AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]) {
        expect(audio.paused, isTrue, reason: r'still silent at $state');
        go(state);
      }
      go(AppLifecycleState.resumed);
      expect(audio.paused, isFalse);
    });

    testWidgets('the audio switch, in the settings, mutes and says so', (
      tester,
    ) async {
      final audio = SilentAudio();
      await tester.pumpWidget(
        StepboundApp(saves: MemorySaveRepository(), audio: audio),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-settings')));
      await tester.pump();
      expect(find.text('AUDIO: SÌ'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('settings-audio')));
      await tester.pump();
      expect(audio.muted, isTrue);
      expect(find.text('AUDIO: NO'), findsOneWidget);
    });

    testWidgets('the credits name every piece of music', (tester) async {
      await tester.pumpWidget(
        StepboundApp(saves: MemorySaveRepository(), audio: SilentAudio()),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('menu-credits')));
      await tester.pump();
      for (final credit in musicCredits) {
        expect(find.textContaining(credit.title), findsOneWidget);
      }
      expect(find.text(effectsCredit), findsOneWidget);
    });
  });
}
