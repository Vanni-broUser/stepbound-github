import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/integer_resolution_viewport.dart';
import 'package:stepbound/game/tutorial/tutorial_director.dart';
import 'package:stepbound/ui/blood_decor.dart';
import 'package:stepbound/ui/main_menu.dart';
import 'package:stepbound/ui/story_intro.dart';

/// One card of the camp's list of zombie types. [kind] is null for the
/// types still to come: they stay "???" until the game has them.
final class ZombieCard {
  const ZombieCard({
    required this.kind,
    required this.name,
    required this.portrait,
    required this.description,
  });

  final EntityKind? kind;
  final String name;
  final String portrait;
  final String description;
}

const String _unknownPortrait = 'assets/story/portrait_wanderer.png';

/// Every card, known or not. Many are still "???": more types will come.
final List<ZombieCard> zombieCards = <ZombieCard>[
  const ZombieCard(
    kind: EntityKind.wanderer,
    name: 'Vagante',
    portrait: 'assets/story/portrait_wanderer.png',
    description:
        'Il più comune: fino a poco fa era una persona qualunque. Lento e '
        'goffo, fa un passo ogni due dei tuoi. Da solo si evita, in gruppo '
        'ti chiude la strada.',
  ),
  const ZombieCard(
    kind: EntityKind.carabiniere,
    name: 'Carabiniere',
    portrait: 'assets/story/portrait_carabiniere.png',
    description:
        'Porta ancora la divisa e stringe il manganello: ti colpisce fino a '
        'due celle di distanza. Si muove come un vagante, ma non lasciarlo '
        'avvicinare.',
  ),
  const ZombieCard(
    kind: EntityKind.sprinter,
    name: 'Veloce',
    portrait: 'assets/story/portrait_sprinter.png',
    description:
        'Si muove alla tua stessa velocità: correndo non lo semini. Ti vede '
        'e ti sente da più lontano degli altri.',
  ),
  const ZombieCard(
    kind: EntityKind.brute,
    name: 'Bruto',
    portrait: _unknownPortrait,
    description: '',
  ),
  const ZombieCard(
    kind: EntityKind.blind,
    name: 'Cieco',
    portrait: _unknownPortrait,
    description: '',
  ),
  for (var i = 0; i < 7; i++)
    const ZombieCard(
      kind: null,
      name: '',
      portrait: _unknownPortrait,
      description: '',
    ),
];

/// A story scene that can be watched again at a camp once it has been
/// seen.
final class Memory {
  const Memory({
    required this.title,
    required this.scenes,
    this.inHypermarket = false,
  });

  final String title;
  final List<StoryScene> scenes;

  /// Luigi's scene: only once it has really been played.
  final bool inHypermarket;
}

/// The memories in the order they are lived.
final List<Memory> memories = <Memory>[
  const Memory(title: 'Il telegiornale', scenes: introScenes),
  const Memory(title: 'La notte del contagio', scenes: outbreakScenes),
  Memory(
    title: 'Luigi al centro commerciale',
    inHypermarket: true,
    scenes: <StoryScene>[
      for (final frame in TutorialDirector.luigiScene)
        StoryScene(
          image: frame.image,
          speaker: frame.speaker,
          text: frame.text,
        ),
    ],
  ),
];

enum _CampPage { home, zombies, confirmRestart }

/// Opens at a campfire, over the game: save, start the level over, look up
/// the zombie types met so far, or watch the story scenes seen so far.
final class CampMenu extends StatefulWidget {
  const CampMenu({
    required this.knownZombies,
    required this.luigiSceneSeen,
    required this.onSave,
    required this.onRestartLevel,
    required this.onClose,
    this.onMemories,
    super.key,
  });

  final Set<EntityKind> knownZombies;
  final bool luigiSceneSeen;
  final Future<void> Function() onSave;
  final VoidCallback onRestartLevel;
  final VoidCallback onClose;

  /// Told true when the memories start playing and false when they end,
  /// so the story's sound can take over from the camp's.
  final ValueChanged<bool>? onMemories;

  @override
  State<CampMenu> createState() => _CampMenuState();
}

final class _CampMenuState extends State<CampMenu> {
  _CampPage _page = _CampPage.home;
  bool _saving = false;
  bool _saved = false;
  int _selectedZombie = 0;
  bool _watchingMemories = false;

  bool _unlocked(Memory memory) =>
      !memory.inHypermarket || widget.luigiSceneSeen;

  /// Every story scene seen so far, one after the other.
  List<StoryScene> get _seenScenes => <StoryScene>[
    for (final memory in memories)
      if (_unlocked(memory)) ...memory.scenes,
  ];

  bool _known(ZombieCard card) =>
      card.kind != null && widget.knownZombies.contains(card.kind);

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave();
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
    }
  }

  void _open(_CampPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    if (_watchingMemories) {
      void back() {
        widget.onMemories?.call(false);
        setState(() => _watchingMemories = false);
      }

      return StoryIntro(
        key: const ValueKey<String>('camp-memories-story'),
        scenes: _seenScenes,
        onFinished: back,
        onExit: back,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxHeight.isFinite
            ? constraints.maxHeight / IntegerResolutionViewport.virtualHeight
            : 1.0;
        // No backdrop: the buttons float over the world, which stays in
        // view.
        return Padding(
          key: const ValueKey<String>('camp-menu'),
          padding: EdgeInsets.all(8 * unit),
          child: switch (_page) {
            _CampPage.zombies => _zombies(unit),
            _ => Center(child: SingleChildScrollView(child: _list(unit))),
          },
        );
      },
    );
  }

  Widget _list(double unit) {
    final items = switch (_page) {
      _CampPage.home => <Widget>[
        MenuButton(
          key: const ValueKey<String>('camp-save'),
          label: _saved ? 'SALVATAGGIO COMPLETATO' : 'SALVA IL GIOCO',
          unit: unit,
          compact: true,
          onPressed: _saving || _saved ? null : () => unawaited(_save()),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-restart'),
          label: 'RICOMINCIA IL LIVELLO',
          unit: unit,
          compact: true,
          onPressed: () => _open(_CampPage.confirmRestart),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-zombies'),
          label: 'TIPI DI ZOMBI',
          unit: unit,
          compact: true,
          onPressed: () => _open(_CampPage.zombies),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-memories'),
          label: 'RIVEDI I RICORDI',
          unit: unit,
          compact: true,
          onPressed: () {
            widget.onMemories?.call(true);
            setState(() => _watchingMemories = true);
          },
        ),
        MenuButton(
          key: const ValueKey<String>('camp-close'),
          label: 'TORNA AL GIOCO',
          unit: unit,
          compact: true,
          onPressed: widget.onClose,
        ),
      ],
      _CampPage.confirmRestart => <Widget>[
        _Panel(
          unit: unit,
          width: MenuButton.fullWidth,
          child: _Paragraph(
            'Ricominciare il livello? Si riparte dalla prima scena della '
            'storia: proiettili, zombi conosciuti e ricordi si azzerano, e '
            "lo slot viene salvato all'inizio del livello.",
            unit: unit,
            center: true,
          ),
        ),
        MenuButton(
          key: const ValueKey<String>('camp-restart-confirm'),
          label: 'SÌ, RICOMINCIA',
          unit: unit,
          compact: true,
          warning: true,
          onPressed: widget.onRestartLevel,
        ),
        _back(unit, label: 'NO'),
      ],
      _CampPage.zombies => const <Widget>[],
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 2.5 * unit),
            child: item,
          ),
      ],
    );
  }

  Widget _back(double unit, {String label = 'INDIETRO'}) => MenuButton(
    key: const ValueKey<String>('camp-back'),
    label: label,
    unit: unit,
    compact: true,
    onPressed: () => _open(_CampPage.home),
  );

  /// The list of cards on the left, the selected one's portrait and
  /// description on the right.
  Widget _zombies(double unit) {
    final card = zombieCards[_selectedZombie];
    final known = _known(card);
    return Column(
      key: const ValueKey<String>('camp-zombie-page'),
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 96 * unit,
                child: ListView.builder(
                  itemCount: zombieCards.length,
                  itemBuilder: (context, index) {
                    final entry = zombieCards[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 3 * unit),
                      child: MenuButton(
                        key: ValueKey<String>('camp-zombie-$index'),
                        label: _known(entry) ? entry.name.toUpperCase() : '???',
                        unit: unit,
                        compact: true,
                        warning: index == _selectedZombie,
                        width: 90,
                        onPressed: () =>
                            setState(() => _selectedZombie = index),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8 * unit),
              Expanded(
                child: _Panel(
                  unit: unit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: known
                            ? Image.asset(
                                card.portrait,
                                key: ValueKey<String>(
                                  'camp-portrait-$_selectedZombie',
                                ),
                                fit: BoxFit.contain,
                              )
                            // Unknown: just a black shape.
                            : ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Color(0xff050303),
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  card.portrait,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                      SizedBox(height: 4 * unit),
                      Text(
                        known ? card.name.toUpperCase() : '???',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: BloodColors.bright,
                          fontFamily: 'monospace',
                          fontSize: 9 * unit,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 2 * unit),
                      _Paragraph(
                        known
                            ? card.description
                            : 'Non hai ancora incontrato questo zombi.',
                        key: const ValueKey<String>('camp-zombie-description'),
                        unit: unit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * unit),
        Align(alignment: Alignment.centerLeft, child: _back(unit)),
      ],
    );
  }
}

/// A dark plate with the blood-red rim of the buttons, so text reads over
/// the world.
final class _Panel extends StatelessWidget {
  const _Panel({required this.unit, required this.child, this.width});

  final double unit;
  final Widget child;

  /// In virtual pixels; as wide as it can be when null.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == null ? null : width! * unit,
      padding: EdgeInsets.all(6 * unit),
      decoration: BoxDecoration(
        color: const Color(0xe6140c0c),
        border: Border.all(color: BloodColors.fresh, width: 1.5 * unit),
        borderRadius: BorderRadius.circular(4 * unit),
      ),
      child: child,
    );
  }
}

final class _Paragraph extends StatelessWidget {
  const _Paragraph(
    this.text, {
    required this.unit,
    this.center = false,
    super.key,
  });

  final String text;
  final double unit;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: TextStyle(
        color: const Color(0xffe8dccb),
        fontFamily: 'monospace',
        fontSize: 7.5 * unit,
        height: 1.3,
        decoration: TextDecoration.none,
      ),
    );
  }
}
