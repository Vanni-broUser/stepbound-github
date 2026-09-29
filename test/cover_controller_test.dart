import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/audio/sound.dart';
import 'package:stepbound/game/cover_controller.dart';
import 'package:stepbound/game/game_cover.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'package:stepbound/report/breadcrumbs.dart';

void main() {
  late int stops;
  late Progress progress;
  late List<StoryMemory> viewed;
  late Breadcrumbs trail;
  late CoverController covers;

  setUp(() {
    stops = 0;
    progress = Progress.newGame();
    viewed = <StoryMemory>[];
    trail = Breadcrumbs();
    covers = CoverController(
      onShow: () => stops++,
      progress: progress,
      onStoryViewed: viewed.add,
      trail: trail,
    );
  });

  tearDown(() => covers.dispose());

  test('nothing covers the game at first', () {
    expect(covers.isCovered, isFalse);
    expect(covers.cover.value, isNull);
  });

  group('the text box', () {
    test('goes up with its lines, stopping Mario, and the trail says so', () {
      covers.showPrompt(const <StoryLine>[
        StoryLine('Ciao Luigi, come va?', speaker: 'Mario Rossi'),
        StoryLine('Bene'),
      ]);
      expect(stops, 1);
      expect(
        covers.cover.value,
        isA<PromptCover>().having((c) => c.lines, 'lines', hasLength(2)),
      );
      expect(
        trail.entries.single.text,
        'battuta: Mario Rossi: Ciao Luigi, come va? (+1)',
      );
    });

    test('a long line is clipped in the trail, an empty box leaves none', () {
      covers.showPrompt(<StoryLine>[StoryLine('a' * 80)]);
      expect(trail.entries.single.text, 'battuta: —: ${'a' * 57}...');
      covers.showPrompt(const <StoryLine>[]);
      expect(trail.entries, hasLength(1));
    });

    test('dismissing it calls back once, and only a text box', () {
      var dismissed = 0;
      covers
        ..showPrompt(const <StoryLine>[
          StoryLine('Ecco'),
        ], onDismissed: () => dismissed++)
        ..dismissPrompt();
      expect(covers.isCovered, isFalse);
      expect(dismissed, 1);
      covers
        ..openZombieBook()
        ..dismissPrompt();
      expect(covers.cover.value, isA<ZombieBookCover>());
      expect(dismissed, 1);
    });
  });

  group('a cutscene', () {
    const frames = <CutsceneFrame>[
      CutsceneFrame(
        image: 'assets/story/scenes/luigi_trapped.jpg',
        text: 'Luigi!',
      ),
    ];

    test('can be skipped only once all its memories were seen', () {
      covers.playCutscene(
        frames,
        memories: const <StoryMemory>{StoryMemory.luigiRescued},
      );
      expect((covers.cover.value! as CutsceneCover).canSkip, isFalse);
      covers.finishCutscene();
      expect(viewed, <StoryMemory>[StoryMemory.luigiRescued]);
      expect(progress.hasViewed(StoryMemory.luigiRescued), isTrue);
      covers.playCutscene(
        frames,
        memories: const <StoryMemory>{StoryMemory.luigiRescued},
      );
      expect((covers.cover.value! as CutsceneCover).canSkip, isTrue);
      covers.playCutscene(frames);
      expect(
        (covers.cover.value! as CutsceneCover).canSkip,
        isFalse,
        reason: 'no memory: never',
      );
    });

    test('says when it is black, then when it is over, in that order', () {
      final log = <String>[];
      covers.playCutscene(
        frames,
        onBlack: () => log.add('black'),
        onFinished: () => log.add('finished'),
        stayBlack: true,
        music: Music.story,
      );
      final scene = covers.cover.value! as CutsceneCover;
      expect(scene.stayBlack, isTrue);
      expect(scene.music, Music.story);
      covers.cutsceneBlack();
      expect(covers.isCovered, isTrue, reason: 'still up while black');
      covers.finishCutscene();
      expect(log, <String>['black', 'finished']);
      expect(covers.isCovered, isFalse);
    });
  });

  test('the work-in-progress screen calls back once it is tapped away', () {
    var closed = 0;
    covers
      ..showWorkInProgress(onClosed: () => closed++)
      ..closeWorkInProgress();
    expect(closed, 1);
    expect(covers.isCovered, isFalse);
  });

  test('the books aboard open and close, each only itself', () {
    covers.openZombieBook();
    expect(covers.cover.value, isA<ZombieBookCover>());
    covers.closeAdventureStats();
    expect(
      covers.cover.value,
      isA<ZombieBookCover>(),
      reason: 'not the figures',
    );
    covers.closeZombieBook();
    expect(covers.isCovered, isFalse);
    covers.openAdventureStats();
    expect(covers.cover.value, isA<AdventureStatsCover>());
    covers.closeAdventureStats();
    expect(covers.isCovered, isFalse);
  });

  test('the memories go back to the figures of their city', () {
    covers.showMemories(LevelId.rome);
    expect(covers.cover.value, isA<MemoriesCover>());
    expect(covers.closeMemories(), isTrue);
    expect(
      covers.cover.value,
      isA<AdventureStatsCover>().having((c) => c.level, 'level', LevelId.rome),
    );
    expect(covers.closeMemories(), isFalse, reason: 'no memories on');
  });

  test('a failed save is told, and the notice calls back when dismissed', () {
    var dismissed = 0;
    covers
      ..showSaveFailed(
        'Salvataggio non riuscito',
        onDismissed: () => dismissed++,
      )
      ..dismissSaveFailed();
    expect(dismissed, 1);
    expect(covers.isCovered, isFalse);
  });

  test('the pause menu opens only over nothing, the wardrobe always', () {
    covers.showPrompt(const <StoryLine>[StoryLine('Ecco')]);
    expect(covers.openMenu(), isFalse);
    expect(covers.cover.value, isA<PromptCover>());
    covers.dismissPrompt();
    expect(covers.openMenu(), isTrue);
    expect(
      covers.cover.value,
      isA<PauseCover>().having((c) => c.wardrobe, 'wardrobe', isFalse),
    );
    covers.closeMenu();
    expect(covers.isCovered, isFalse);
    covers.openWardrobe();
    expect(
      covers.cover.value,
      isA<PauseCover>().having((c) => c.wardrobe, 'wardrobe', isTrue),
    );
  });

  test(
    'game over goes over whatever is up, without stopping anything more',
    () {
      covers.openZombieBook();
      final before = stops;
      covers.gameOver();
      expect(covers.cover.value, isA<GameOverCover>());
      expect(stops, before);
      covers.closeMenu();
      expect(
        covers.cover.value,
        isA<GameOverCover>(),
        reason: 'nothing takes it down',
      );
    },
  );
}
