import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/follow_camera.dart';
import 'package:stepbound/game/render/level_background_component.dart';
import 'package:stepbound/game/render/lighting_component.dart';

/// What is drawn of every place: its baked background, what of it stands
/// in front of the characters and, indoors unless the place is lit
/// throughout, the darkness its lamps cut into. Only the
/// places in view are drawn: the others lie far away on the shared grid and
/// would cost a big image, or a full-room layer, every frame for nothing.
final class PlaceLayers {
  PlaceLayers({
    required Iterable<Place> places,
    required this.playerFeet,
    bool Function(Place place)? useAlternateBackground,
  }) : _layers = <_Layers>[
         for (final place in places)
           (
             area: pixelRect(place.bounds),
             background: LevelBackgroundComponent(
               assetPath: place.background,
               alternateAssetPath: place.alternateBackground,
               useAlternate: place.alternateBackground == null
                   ? null
                   : () => useAlternateBackground?.call(place) ?? false,
               offset: Offset(
                 pixelRect(place.bounds).left,
                 pixelRect(place.bounds).top,
               ),
             ),
             foreground: switch (place.foreground) {
               null => null,
               final path => LevelBackgroundComponent(
                 assetPath: path,
                 offset: Offset(
                   pixelRect(place.bounds).left,
                   pixelRect(place.bounds).top,
                 ),
                 priority: foregroundPriority,
               ),
             },
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

  /// Over the characters (20), under the fires (25).
  static const int foregroundPriority = 22;

  /// Where Mario's feet are, in pixels, for the glow around him indoors.
  final Vector2 Function() playerFeet;
  final List<_Layers> _layers;

  List<Component> get components => <Component>[
    for (final layer in _layers) ...<Component>[
      layer.background,
      ?layer.foreground,
      ?layer.lighting,
    ],
  ];

  /// Shows only the places that overlap the camera's [view].
  void cull(Rect view) {
    for (final layer in _layers) {
      final onScreen = layer.area.overlaps(view);
      layer.background.onScreen = onScreen;
      layer.foreground?.onScreen = onScreen;
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
  LevelBackgroundComponent background,
  LevelBackgroundComponent? foreground,
  LightingComponent? lighting,
});
