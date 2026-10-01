import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/progress.dart';
import 'package:stepbound/game/story/story_director.dart';
import 'story_harness.dart';

void main() {
  setUp(startStory);

  void pickUpTheIngot() {
    director.onEvents(<WorldEvent>[
      pickedUp(bankIngotBackpackId, goldIngot: true),
    ]);
    settle();
  }

  test('the gold ingot in the vault is told, then Mario says what it is '
      'for, and it goes up among what he carries', () {
    progress.view(StoryMemory.maranzaMet);
    pickUpTheIngot();
    expect(host.pickupAnimations, 1);
    final lines = host.shown.single;
    expect(lines.map((line) => line.text), <String>[
      "Hai trovato un lingotto d'oro",
      BackpacksScript.goldIngotThought,
    ]);
    expect(
      BackpacksScript.goldIngotThought,
      'Questo andrà bene per quei due maranza. Non penso di poterne fare '
      "qualcos'altro",
    );
    expect(lines.first.speaker, isNull, reason: 'the tutorial box');
    expect(lines.last.speaker, 'Mario Rossi');
    expect(host.unlocked, contains(HudElement.goldIngot));
    expect(HudElement.goldIngot.level, LevelId.rome);
  });

  test('found before meeting the two of them, Mario does not know what '
      'to do with it, and still carries it', () {
    pickUpTheIngot();
    expect(host.shown.single.map((line) => line.text), <String>[
      "Hai trovato un lingotto d'oro",
      BackpacksScript.goldIngotPuzzled,
    ]);
    expect(
      BackpacksScript.goldIngotPuzzled,
      "Wow un lingotto d'oro... ma cosa me ne faccio?",
    );
    expect(host.shown.single.last.speaker, 'Mario Rossi');
    expect(host.unlocked, contains(HudElement.goldIngot));
  });

  test('with the two of them met, finding the ingot does not do the '
      'mission: taking it to them does', () {
    progress.missions.give(Mission.findValuable);
    pickUpTheIngot();
    host.dismiss();
    settle();
    expect(progress.missions.isOpen(Mission.findValuable), isTrue);
  });

  test('found before meeting them, it hands out no mission of its own', () {
    pickUpTheIngot();
    host.dismiss();
    settle();
    expect(progress.missions.isOpen(Mission.findValuable), isFalse);
    expect(progress.missions.isDone(Mission.findValuable), isFalse);
  });
}
