import 'package:stepbound/core/core.dart';
import 'package:stepbound/l10n/language.dart';

/// Everything the game tells about one zombie type, in one place, so that
/// a new type cannot be half introduced. The first time one is met the
/// story director's `introduceZombie` does all of it together:
///
/// 1. records the type in `Progress.knownZombies`, which a save keeps and
///    the book on the train reads (its card stops being "???");
/// 2. frames the zombie together with Mario;
/// 3. shows [lesson] with [portrait] over the text box, and gives the
///    camera back to Mario once it is dismissed.
///
/// [introducedOnSight] types get that the moment one is first on screen,
/// anywhere in the game. The others have a scene of their own, told by the
/// script of their place: the wanderer on the first street when it spots
/// Mario, the carabiniere in the barracks when one becomes aware of him.
final class ZombieLore {
  const ZombieLore({
    required this.kind,
    required this.portrait,
    this.introducedOnSight = false,
  });

  final EntityKind kind;

  /// Its name in the book.
  String get name => strings.zombieName(kind);

  /// Shown over its lesson and on its card in the book.
  final String portrait;

  /// The line shown the first time it is met.
  String get lesson => strings.zombieLesson(kind);

  /// Its card in the book.
  String get description => strings.zombieDescription(kind);

  final bool introducedOnSight;
}

/// The zombie types the game has, in the order the book lists them.
const Map<EntityKind, ZombieLore> zombieLore = <EntityKind, ZombieLore>{
  EntityKind.wanderer: ZombieLore(
    kind: EntityKind.wanderer,
    portrait: 'assets/characters/zombies/portraits/wanderer.png',
  ),
  EntityKind.carabiniere: ZombieLore(
    kind: EntityKind.carabiniere,
    portrait: 'assets/characters/zombies/portraits/carabiniere.png',
  ),
  EntityKind.sprinter: ZombieLore(
    kind: EntityKind.sprinter,
    portrait: 'assets/characters/zombies/portraits/sprinter.png',
    introducedOnSight: true,
  ),
  EntityKind.mutilated: ZombieLore(
    kind: EntityKind.mutilated,
    portrait: 'assets/characters/zombies/portraits/mutilated.png',
    introducedOnSight: true,
  ),
  EntityKind.burning: ZombieLore(
    kind: EntityKind.burning,
    portrait: 'assets/characters/zombies/portraits/burning.png',
    introducedOnSight: true,
  ),
  EntityKind.drunk: ZombieLore(
    kind: EntityKind.drunk,
    portrait: 'assets/characters/zombies/portraits/drunk.png',
    introducedOnSight: true,
  ),
  EntityKind.cultist: ZombieLore(
    kind: EntityKind.cultist,
    portrait: 'assets/characters/zombies/portraits/cultist.png',
    introducedOnSight: true,
  ),
  EntityKind.brute: ZombieLore(
    kind: EntityKind.brute,
    portrait: 'assets/characters/zombies/portraits/brute.png',
    introducedOnSight: true,
  ),
  EntityKind.callCenter: ZombieLore(
    kind: EntityKind.callCenter,
    portrait: 'assets/characters/zombies/portraits/call_center.png',
    introducedOnSight: true,
  ),
};
