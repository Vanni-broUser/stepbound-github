import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/level_background_component.dart';
import 'package:stepbound/game/render/lighting_component.dart';
import 'package:stepbound/game/render/place_background.dart';
import 'package:stepbound/game/render/tile_place_component.dart';

/// What is drawn of every place: its background and, indoors unless the
/// place is lit throughout, the darkness its lamps cut into. A place with
/// a baked picture is drawn from it; a converted place is painted from its
/// own ASCII rows out of the tile atlas. Only the places in view are
/// drawn: the others lie far away on the shared grid and would cost a big
/// image, or a full-room layer, every frame for nothing.
final class PlaceLayers {
  PlaceLayers({
    required Iterable<Place> places,
    required this.playerFeet,
    bool Function(Place place)? useAlternateBackground,
  }) : _layers = <_Layers>[
         for (final place in places)
           (
             area: pixelRect(place.bounds),
             background: _backgroundOf(place, useAlternateBackground),
             lighting: place.indoor && !place.lit
                 ? LightingComponent(
                     area: pixelRect(place.bounds),
                     lights: place.lights,
                     darkness: place.darkness,
                     playerPosition: playerFeet,
                   )
                 : null,
           ),
       ];

  static PlaceBackground _backgroundOf(
    Place place,
    bool Function(Place place)? useAlternate,
  ) {
    final corner = Offset(
      pixelRect(place.bounds).left,
      pixelRect(place.bounds).top,
    );
    final baked = place.background;
    if (baked == null) {
      return TilePlaceComponent(
        place: place,
        offset: corner,
        useOpen: () => useAlternate?.call(place) ?? false,
      );
    }
    return LevelBackgroundComponent(
      assetPath: baked,
      alternateAssetPath: place.alternateBackground,
      useAlternate: place.alternateBackground == null
          ? null
          : () => useAlternate?.call(place) ?? false,
      offset: corner,
    );
  }

  /// Where Mario's feet are, in pixels, for the glow around him indoors.
  final Vector2 Function() playerFeet;
  final List<_Layers> _layers;

  List<Component> get components => <Component>[
    for (final layer in _layers) ...<Component>[
      layer.background,
      ?layer.lighting,
    ],
  ];

  /// Shows only the places that overlap the camera's [view].
  void cull(Rect view) {
    for (final layer in _layers) {
      final onScreen = layer.area.overlaps(view);
      layer.background.onScreen = onScreen;
      layer.lighting?.onScreen = onScreen;
    }
  }

  /// The backgrounds being drawn.
  List<String> get drawn => <String>[
    for (final layer in _layers)
      if (layer.background.onScreen) layer.background.activeAssetPath,
  ];
}

typedef _Layers = ({
  Rect area,
  PlaceBackground background,
  LightingComponent? lighting,
});
