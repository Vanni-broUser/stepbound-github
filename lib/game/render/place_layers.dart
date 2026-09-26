import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/lighting_component.dart';
import 'package:stepbound/game/render/tile_place_component.dart';

/// What is drawn of every place: its background, painted from its own
/// ASCII rows out of the tile atlas, what of it stands in front of the
/// characters, and, indoors unless the place is lit
/// throughout, the darkness its lamps cut into.
///
/// A place's pictures are big, so only some places have them at a time:
/// those of the area Mario is in, and those one door away from it, so
/// whichever door he takes opens on a place that is ready. The rest are
/// taken out of the world and their images let go (see [settle]). Of the
/// places loaded, only those in view are drawn: the others lie far away on
/// the shared grid and would cost a big image, or a full-room layer, every
/// frame for nothing.
final class PlaceLayers {
  PlaceLayers({
    required this.places,
    required this.playerFeet,
    this.showOpened,
  });

  /// Every place of the game.
  final List<Place> places;

  /// Where Mario's feet are, in pixels, for the glow around him indoors.
  final Vector2 Function() playerFeet;

  /// Whether the story has opened what [Place] can open.
  final bool Function(Place place)? showOpened;

  final Map<Place, _Layers> _loaded = <Place, _Layers>{};
  AreaId? _area;

  /// How long the last area took to be composed, once it has: for
  /// measuring on a phone.
  Duration? lastLoad;

  /// The places kept loaded while Mario is in [shown]: all those of its
  /// area, and those the doors out of the area lead to. The doors are
  /// [portals], as the world has them now: the train's leads to the
  /// station of whichever level it stands in.
  static Set<Place> kept(
    Place shown,
    Iterable<Place> places,
    Map<GridPoint, Portal> portals,
  ) {
    final area = <Place>{
      for (final place in places)
        if (place.area == shown.area) place,
    };
    Place? at(GridPoint tile) {
      for (final place in places) {
        if (place.bounds.contains(tile)) {
          return place;
        }
      }
      return null;
    }

    return <Place>{
      ...area,
      for (final MapEntry(key: from, value: portal) in portals.entries)
        if (area.any((place) => place.bounds.contains(from))) ?at(portal.to),
    };
  }

  /// Loads the places Mario needs in [shown] into [world], and takes out
  /// those he no longer does. Nothing happens while he stays in the same
  /// area. Completes once the new places are composed.
  Future<void> settle(
    Place shown,
    Map<GridPoint, Portal> portals,
    Component world,
  ) async {
    if (shown.area == _area) {
      return;
    }
    _area = shown.area;
    final wanted = kept(shown, places, portals);
    TilePlaceComponent.keepOnly(wanted);
    for (final place in _loaded.keys.toList()) {
      if (!wanted.contains(place)) {
        final layers = _loaded.remove(place)!;
        for (final component in layers.components) {
          component.removeFromParent();
        }
        layers.background.release();
      }
    }
    final added = <_Layers>[
      for (final place in wanted)
        if (!_loaded.containsKey(place)) _loaded[place] = _layersOf(place),
    ];
    if (added.isEmpty) {
      return;
    }
    final clock = Stopwatch()..start();
    final components = added.expand((layers) => layers.components).toList();
    await world.addAll(components);
    await Future.wait(components.map((component) => component.loaded));
    lastLoad = clock.elapsed;
  }

  _Layers _layersOf(Place place) {
    final area = pixelRect(place.bounds);
    final background = TilePlaceComponent(
      place: place,
      offset: Offset(area.left, area.top),
      useOpen: () => showOpened?.call(place) ?? false,
    );
    return (
      area: area,
      background: background,
      lighting: place.indoor && !place.lit
          ? LightingComponent(
              area: area,
              lights: place.lights,
              darkness: place.darkness,
              playerPosition: playerFeet,
            )
          : null,
    );
  }

  /// The places whose pictures are in memory now.
  Iterable<PlaceId> get loaded => _loaded.keys.map((place) => place.id);

  /// Shows only the places that overlap the camera's [view].
  void cull(Rect view) {
    for (final layer in _loaded.values) {
      final onScreen = layer.area.overlaps(view);
      layer.background.onScreen = onScreen;
      layer.lighting?.onScreen = onScreen;
    }
  }

  /// The backgrounds being drawn.
  List<String> get drawn => <String>[
    for (final layer in _loaded.values)
      if (layer.background.onScreen) layer.background.activeAssetPath,
  ];
}

typedef _Layers = ({
  Rect area,
  TilePlaceComponent background,
  LightingComponent? lighting,
});

extension on _Layers {
  List<Component> get components => <Component>[
    background,
    background.front,
    ?lighting,
  ];
}
