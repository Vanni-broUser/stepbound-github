/// The sounds of the game, baked by `tools/build_audio.py` into
/// `assets/audio/`. Paths are relative to that folder.
library;

import 'package:stepbound/l10n/language.dart';

/// Looping music; only one plays at a time and a change crossfades.
enum Music {
  menu('music/menu.mp3'),
  story('music/story.mp3'),
  street('music/street.mp3'),
  barracks('music/barracks.mp3'),
  danger('music/danger.mp3'),

  /// Organ and choir gone wrong: San Nicola, the Duomo and Don Angelo.
  sacred('music/sacred.mp3'),

  /// Setting off together: Luigi, the station and the train.
  luigi('music/luigi.mp3'),

  /// Chords like Gregorian chant under a cold organ, a harp plucking
  /// alone: Rome, from Termini out into its streets.
  rome('music/rome.mp3'),

  /// A catchy beat to rap over, all swagger: Tonino and Marcello, in
  /// their scenes and whenever they come into view once they are known.
  maranza('music/maranza.mp3'),

  /// Pizzicato tiptoeing like a cartoon villain, slowed down: the hold
  /// music of a call centre gone wrong. Inside the company, and Chiara's
  /// scenes and their memories: never out in the street.
  weasel('music/weasel.mp3');

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

  /// A rocket leaving the launcher: the thump of the charge and the roar
  /// of its motor going off down the line.
  rocket(<String>['sfx/rocket_launch.mp3']),

  /// The rocket bursting against the wall at the end of its line.
  explosion(<String>['sfx/explosion.mp3']),

  /// A bottle shattering and the petrol catching.
  molotov(<String>['sfx/molotov_1.mp3', 'sfx/molotov_2.mp3']),
  dryFire(<String>['sfx/dry_fire.mp3'], volume: 0.8),
  pickup(<String>['sfx/pickup.mp3'], volume: 0.8),
  pickupGun(<String>['sfx/pickup_gun.mp3'], volume: 0.9),
  door(<String>['sfx/door.mp3'], volume: 0.8),

  /// The grappling hook: the rope through the air, the hook catching on
  /// the stone across the gap, the rope creaking as Mario goes over.
  grapple(<String>['sfx/grapple.mp3'], volume: 0.9),
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

  /// A pen drawn lightly across paper: one stroke of a mission's cross,
  /// quiet under whatever else is playing.
  penStroke(<String>[
    'sfx/pen_stroke_1.mp3',
    'sfx/pen_stroke_2.mp3',
  ], volume: 0.35),
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
///
/// A null licence is a piece its author asks only to be credited for.
typedef SoundCredit = ({String title, String author, String? licence});

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
    title: 'Halls of the Undead',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'At Launch',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Rites',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Basic Implosion',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Scheming Weasel (slower version)',
    author: 'Kevin MacLeod (incompetech.com)',
    licence: 'CC BY 4.0',
  ),
  (
    title: 'Lurking in the Shadows',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: null,
  ),
  (
    title: 'Closing In',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: null,
  ),
  (
    title: 'Horrible Realization',
    author: 'Eric Matyas (www.soundimage.org)',
    licence: null,
  ),
];

/// The effects are public domain; they are credited as a courtesy.
String get effectsCredit => strings.creditsEffects;
