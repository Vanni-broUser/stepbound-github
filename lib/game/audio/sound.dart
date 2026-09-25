/// The sounds of the game, baked by `tools/build_audio.py` into
/// `assets/audio/`. Paths are relative to that folder.
library;

/// Looping music; only one plays at a time and a change crossfades.
enum Music {
  menu('music/menu.mp3'),
  story('music/story.mp3'),
  street('music/street.mp3'),
  barracks('music/barracks.mp3'),
  danger('music/danger.mp3');

  const Music(this.file);

  final String file;
}

/// Looping background noise; several can play together, each at its own
/// volume.
enum Ambience {
  wind('ambience/wind.mp3'),
  indoor('ambience/indoor.mp3'),
  fire('ambience/fire.mp3');

  const Ambience(this.file);

  final String file;
}

/// One-shot effects. A sound with several [files] plays one of them at
/// random, so repeated steps or groans never sound mechanical.
enum Sfx {
  step(
    <String>[
      'sfx/step_1.mp3',
      'sfx/step_2.mp3',
      'sfx/step_3.mp3',
      'sfx/step_4.mp3',
    ],
    volume: 0.45,
    voices: 4,
  ),
  gunshot(<String>['sfx/gunshot.mp3']),
  dryFire(<String>['sfx/dry_fire.mp3'], volume: 0.8),
  pickup(<String>['sfx/pickup.mp3'], volume: 0.8),
  pickupGun(<String>['sfx/pickup_gun.mp3'], volume: 0.9),
  door(<String>['sfx/door.mp3'], volume: 0.8),
  rest(<String>['sfx/rest.mp3'], volume: 0.7),
  zombieAlert(
    <String>[
      'sfx/zombie_alert_1.mp3',
      'sfx/zombie_alert_2.mp3',
      'sfx/zombie_alert_3.mp3',
    ],
    volume: 0.85,
    voices: 3,
  ),
  zombieHurt(<String>[
    'sfx/zombie_hurt_1.mp3',
    'sfx/zombie_hurt_2.mp3',
  ], volume: 0.8),
  zombieDeath(<String>['sfx/zombie_death.mp3'], volume: 0.85),
  zombieBite(<String>['sfx/zombie_bite.mp3']),
  hitFlesh(<String>['sfx/hit_flesh.mp3'], volume: 0.8),
  playerHurt(<String>['sfx/player_hurt.mp3']),
  playerFall(<String>['sfx/player_fall.mp3']),
  gameOver(<String>['sfx/game_over.mp3'], voices: 1, lingers: true),
  uiClick(<String>['sfx/ui_click.mp3'], volume: 0.6),
  dialogue(<String>['sfx/dialogue.mp3'], volume: 0.5);

  const Sfx(
    this.files, {
    this.volume = 1,
    this.voices = 2,
    this.lingers = false,
  });

  final List<String> files;

  /// Mix level of this sound, multiplied by the volume it is played at.
  final double volume;

  /// How many copies of one file can overlap.
  final int voices;

  /// Long enough to play on over what comes next: the game over sting, half
  /// a minute. Every copy is kept track of, so that `GameAudio.stop` and the
  /// app going to the background can cut it; a new copy cuts the old one.
  final bool lingers;
}

/// A credit line for the in-game credits screen.
typedef SoundCredit = ({String title, String author, String licence});

/// Every piece of music, as its licence requires it to be credited in the
/// game itself.
const List<SoundCredit> musicCredits = <SoundCredit>[
  (
    title: 'Darkest Child',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Gathering Darkness',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Oppressive Gloom',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Lurking in the Shadows',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: 'Con attribuzione',
  ),
  (
    title: 'Closing In',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: 'Con attribuzione',
  ),
  (
    title: 'Horrible Realization',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: 'Con attribuzione',
  ),
];

/// The effects are public domain; they are credited as a courtesy.
const String effectsCredit =
    'Effetti sonori: Kenney.nl e OpenGameArt.org (CC0)';
