import 'package:flutter_test/flutter_test.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/crucified_zombie_component.dart';

/// Runs [component] for [seconds] in small steps, as the game loop does.
void run(CrucifiedZombieComponent component, double seconds) {
  for (var elapsed = 0.0; elapsed < seconds; elapsed += 1 / 60) {
    component.update(1 / 60);
  }
}

/// Runs it until its next fit starts, and says how long that took. It gives
/// up well past the longest rest, so a component that never thrashes fails
/// the test instead of hanging it.
double runUntilItThrashes(CrucifiedZombieComponent component) {
  var seconds = 0.0;
  while (!component.isTwitching &&
      seconds < CrucifiedZombieComponent.maxRest * 2) {
    component.update(1 / 60);
    seconds += 1 / 60;
  }
  return seconds;
}

void main() {
  CrucifiedZombieComponent hanging({int seed = 7, void Function()? onTwitch}) =>
      CrucifiedZombieComponent(
        tile: const GridPoint(4, 2),
        seed: seed,
        onTwitch: onTwitch,
      );

  test('it hangs still, breathing between its two still frames', () {
    final cross = hanging();

    expect(cross.isTwitching, isFalse);
    expect(cross.frame, 0);
    run(cross, CrucifiedZombieComponent.breathSeconds);
    expect(cross.frame, 1, reason: 'the second of the two');
    expect(cross.isTwitching, isFalse);
    run(cross, CrucifiedZombieComponent.breathSeconds);
    expect(cross.frame, 0);
  });

  test('every few seconds it thrashes, and says so once per fit', () {
    var fits = 0;
    final cross = hanging(onTwitch: () => fits++);

    run(cross, CrucifiedZombieComponent.minRest - 0.1);
    expect(fits, 0, reason: 'never sooner than the shortest rest');
    expect(cross.isTwitching, isFalse);

    final waited =
        CrucifiedZombieComponent.minRest - 0.1 + runUntilItThrashes(cross);
    expect(fits, 1);
    expect(
      waited,
      lessThanOrEqualTo(CrucifiedZombieComponent.maxRest + 0.1),
      reason: 'nor later than the longest rest',
    );

    // The fit itself is one fit, however long it lasts.
    run(cross, CrucifiedZombieComponent.twitchSeconds - 0.1);
    expect(fits, 1);
  });

  test('a fit runs through its own frames, then it hangs again', () {
    final cross = hanging();
    runUntilItThrashes(cross);
    expect(cross.isTwitching, isTrue);
    expect(cross.frame, 2);

    run(cross, CrucifiedZombieComponent.twitchFrameSeconds);
    expect(cross.frame, 3, reason: 'the other half of the fit');

    run(cross, CrucifiedZombieComponent.twitchSeconds);
    expect(cross.isTwitching, isFalse);
    expect(cross.frame, lessThan(2), reason: 'hanging still again');
  });

  test('two crosses do not thrash together: each has its own rhythm', () {
    final waits = <double>[
      for (final seed in <int>[1, 2, 3])
        runUntilItThrashes(hanging(seed: seed)),
    ];

    expect(waits.toSet(), hasLength(greaterThan(1)), reason: 'not in step');
    for (final waited in waits) {
      expect(
        waited,
        inInclusiveRange(
          CrucifiedZombieComponent.minRest - 0.1,
          CrucifiedZombieComponent.maxRest + 0.1,
        ),
      );
    }
  });
}
