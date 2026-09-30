import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/tile_atlas.dart';

/// Draws a place tile by tile out of the atlas, from the same ASCII rows
/// the simulation walks on: there is no picture of it anywhere, this
/// builds one.
///
/// It is built once, into an image the size of the place, and drawn from
/// there: a tile loop every frame would cost a thousand draws on the
/// cheapest phone we support, and buy nothing. A place whose story can
/// open something -- the train Luigi is in -- is built twice, shut and
/// open, and the flip is then only a choice of image.
///
/// What stands taller than its own cell -- a traffic light's head, a road
/// sign, a tree, a column, a statue, the airliner's hull -- is drawn a
/// second time into
/// [front], wherever it covers a cell someone can walk on: that layer goes
/// over the characters, so one standing behind it is hidden by it.
final class TilePlaceComponent extends Component {
  TilePlaceComponent({
    required this.place,
    this.offset = ui.Offset.zero,
    this.useOpen,
  }) : super(priority: 0);

  /// Cleared by the game while the place is out of the camera's view, so
  /// the far places' big images are not drawn every frame.
  bool onScreen = true;

  final Place place;
  final ui.Offset offset;

  /// Whether the story has opened what this place can open.
  final bool Function()? useOpen;

  ui.Image? _shut;
  ui.Image? _open;
  ui.Image? _frontShut;
  ui.Image? _frontOpen;

  /// What of this place is drawn over the characters, to be added to the
  /// world beside it.
  late final TilePlaceFront front = TilePlaceFront(this);
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  /// The name this place's art goes by in the atlas manifest: its own,
  /// or that of the place it borrows its art from.
  String get artKey => place.artId.name;

  /// What is on screen for this place, for tests and diagnostics.
  String get activeAssetPath =>
      _opened ? 'tiles:$artKey:open' : 'tiles:$artKey';

  bool get _opened => useOpen?.call() ?? false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final loaded = await loadTileAtlas();
    final art = loaded.manifest.places[artKey];
    if (art == null) {
      throw StateError(
        '${place.id} has no baked background and no art in '
        '$tileAtlasManifestPath: run python tools/build_tile_atlas.py',
      );
    }
    final shut = await _drawn(loaded, art, opened: false);
    final open = art.objects.any((object) => object.whenOpen != null)
        ? await _drawn(loaded, art, opened: true)
        : null;
    _shut = shut.$1;
    _frontShut = shut.$2;
    _open = open?.$1;
    _frontOpen = open?.$2;
    // Let go of while it was being drawn: what it would hold is not kept.
    if (_released) {
      release();
    }
  }

  bool _released = false;

  /// Taken out of the world, for whatever reason: the images go with it.
  @override
  void onRemove() {
    release();
    super.onRemove();
  }

  /// Lets go of this place's images: the game calls it when the place is
  /// taken out of the world, having left its area, and [onRemove] calls it
  /// when the world itself is taken down.
  void release() {
    _released = true;
    for (final image in <ui.Image?>[_shut, _open, _frontShut, _frontOpen]) {
      image?.dispose();
    }
    _shut = _open = _frontShut = _frontOpen = null;
  }

  /// The images already built, for the atlas they were built from: a place
  /// looks the same in every game, so the game started at a campfire, or
  /// after a game over, draws the ones the last game built. Building them
  /// again each time was slow. Only the places the game keeps loaded stay
  /// here: see [keepOnly].
  static final Map<(Place, bool), _Built> _built = <(Place, bool), _Built>{};
  static LoadedTileAtlas? _builtFrom;

  /// Drops the images built for any place but [places]. A component
  /// drawing one holds a handle of its own, and one still waiting for it
  /// gets it: the images go once nobody needs them.
  static void keepOnly(Set<Place> places) {
    final gone = _built.keys.where((key) => !places.contains(key.$1)).toList();
    for (final key in gone) {
      _built.remove(key)!.drop();
    }
  }

  /// This place's images, as handles of the caller's own: the cache can
  /// then drop its own while the caller still draws them.
  Future<(ui.Image, ui.Image)> _drawn(
    LoadedTileAtlas loaded,
    TilePlaceArt art, {
    required bool opened,
  }) async {
    if (!identical(loaded, _builtFrom)) {
      for (final built in _built.values) {
        built.drop();
      }
      _built.clear();
      _builtFrom = loaded;
    }
    final built = _built[(place, opened)] ??= _Built(
      _draw(loaded, art, opened: opened),
    );
    built.users++;
    try {
      final images = await built.images;
      return (images.$1.clone(), images.$2.clone());
    } finally {
      built.users--;
      built.disposeIfDropped();
    }
  }

  /// Which tile of a bucket falls on a cell: a hash of its place in the
  /// grid, so the grit lies the same way at every start and there is
  /// nothing to save. tools/build_tile_atlas.py repeats this.
  static int _variant(int length, int x, int y) =>
      ((x * 73856093) ^ (y * 19349663)) % length;

  /// The place, and what of it stands in front of the characters.
  Future<(ui.Image, ui.Image)> _draw(
    LoadedTileAtlas loaded,
    TilePlaceArt art, {
    required bool opened,
  }) async {
    final manifest = loaded.manifest;
    final grid = art.gridFor(place.rows);
    final width = grid.width * manifest.tileWidth;
    final height = grid.height * manifest.tileHeight;
    final behind = await _cellsBehindObjects(loaded, art, grid, opened);
    final recorder = ui.PictureRecorder();
    final frontRecorder = ui.PictureRecorder();
    final frontCanvas = ui.Canvas(frontRecorder);
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..color = art.voidColour,
      );
    _drawLayer(canvas, loaded, art, grid, 'ground');
    // A column, a statue, a wardrobe or a desk is a structure, but it
    // stands taller than its cell all the same: its top leans into the
    // front like a tree's. Not a doorway's lintel, though -- one walks
    // through that, and the feet would vanish on the step before it --
    // and not the ground, which lies flat.
    _drawLayer(
      canvas,
      loaded,
      art,
      grid,
      'structures',
      front: frontCanvas,
      solidOnly: true,
    );
    _drawObjects(canvas, loaded, art, grid, opened: opened);
    _drawObjects(
      frontCanvas,
      loaded,
      art,
      grid,
      opened: opened,
      behind: behind,
    );
    for (final layer in <String>['foreground', 'overhead']) {
      _drawLayer(canvas, loaded, art, grid, layer, front: frontCanvas);
    }
    // What hangs over everything, the characters too.
    for (final target in <ui.Canvas>[canvas, frontCanvas]) {
      _drawObjects(target, loaded, art, grid, opened: opened, overhead: true);
    }
    // Where a map that is not a rectangle has no place, nothing: the
    // screen's own black, as past its edge.
    final offMap = ui.Paint()..blendMode = ui.BlendMode.clear;
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        if (grid.glyphAt(x, y) == Legend.offMap) {
          final cell = ui.Rect.fromLTWH(
            x * manifest.tileWidth.toDouble(),
            y * manifest.tileHeight.toDouble(),
            manifest.tileWidth.toDouble(),
            manifest.tileHeight.toDouble(),
          );
          canvas.drawRect(cell, offMap);
          frontCanvas.drawRect(cell, offMap);
        }
      }
    }
    Future<ui.Image> image(ui.Picture picture) async {
      final image = await picture.toImage(width, height);
      picture.dispose();
      return image;
    }

    final background = await image(recorder.endRecording());
    // Behind an object, the feet are out of sight all along the bottom of
    // the cell: where the object's edge runs down to the feet line, a
    // shoe would otherwise poke out from behind it.
    final composed = ui.PictureRecorder();
    final frontComposed = ui.Canvas(composed)
      ..drawPicture(frontRecorder.endRecording());
    final tileWidth = manifest.tileWidth.toDouble();
    final tileHeight = manifest.tileHeight.toDouble();
    for (final (x, y) in behind.expand((cells) => cells)) {
      final strip = ui.Rect.fromLTWH(
        x * tileWidth,
        (y + 1) * tileHeight - hiddenFeet,
        tileWidth,
        hiddenFeet,
      );
      frontComposed.drawImageRect(background, strip, strip, _paint);
    }
    return (background, await image(composed.endRecording()));
  }

  /// How many rows of pixels at the bottom of a cell behind an object the
  /// object hides: the feet of whoever stands there.
  static const double hiddenFeet = 3;

  /// Whether someone can stand on the cell [x], [y] of [grid].
  bool _walkable(GlyphGrid grid, int x, int y) =>
      Tile(place.kindOf(grid.glyphAt(x, y))).isWalkable;

  void _drawLayer(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    TilePlaceArt art,
    GlyphGrid grid,
    String layer, {
    ui.Canvas? front,
    bool solidOnly = false,
  }) {
    final rules = art.rules.where((rule) => rule.layer == layer).toList();
    if (rules.isEmpty) {
      return;
    }
    // Which rules a glyph can meet, in their order, so a city of a few
    // thousand cells does not ask every rule about every one of them.
    final byGlyph = <String, List<int>>{};
    final byGround = <String, List<int>>{};
    for (var i = 0; i < rules.length; i++) {
      final index = rules[i].onGround ? byGround : byGlyph;
      for (final glyph in rules[i].glyphs.split('')) {
        (index[glyph] ??= <int>[]).add(i);
      }
    }
    const none = <int>[];
    final batch = _TileBatch(loaded.manifest);
    final frontBatch = front == null ? null : _TileBatch(loaded.manifest);
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        final fromGlyph = byGlyph[grid.glyphAt(x, y)] ?? none;
        final fromGround = byGround[grid.groundAt(x, y)] ?? none;
        var a = 0;
        var b = 0;
        while (a < fromGlyph.length || b < fromGround.length) {
          final int next;
          if (b >= fromGround.length ||
              (a < fromGlyph.length && fromGlyph[a] < fromGround[b])) {
            next = fromGlyph[a++];
          } else {
            next = fromGround[b++];
          }
          _drawRule(
            batch,
            grid,
            rules[next],
            x,
            y,
            front: solidOnly && _walkable(grid, x, y) ? null : frontBatch,
          );
        }
      }
    }
    batch.flush(canvas, loaded.atlas, _paint);
    if (front != null) {
      frontBatch!.flush(front, loaded.atlas, _paint);
    }
  }

  void _drawRule(
    _TileBatch batch,
    GlyphGrid grid,
    TileRule rule,
    int x,
    int y, {
    _TileBatch? front,
  }) {
    final index = rule.bucketIndex(grid, x, y);
    final bucket = rule.buckets[index];
    if (bucket.isEmpty) {
      return;
    }
    final variant = _variant(bucket.length, x, y);
    batch.add(bucket[variant], x, y);
    // The rest of the picture, in the same variant: drawn now, so what a
    // tile leans out over the row above lies over what that row drew.
    for (final piece in rule.pieces) {
      final tiles = piece.buckets[index];
      final px = x + piece.dx;
      final py = y + piece.dy;
      if (tiles.isNotEmpty &&
          px >= 0 &&
          py >= 0 &&
          px < grid.width &&
          py < grid.height) {
        batch.add(tiles[variant], px, py);
        // Leaning out over the row above, onto a cell one can walk on:
        // whoever stands there is behind it.
        if (front != null && piece.dy < 0 && _walkable(grid, px, py)) {
          front.add(tiles[variant], px, py);
        }
      }
    }
  }

  void _drawObjects(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    TilePlaceArt art,
    GlyphGrid grid, {
    required bool opened,
    List<Set<(int, int)>>? behind,
    bool overhead = false,
  }) {
    for (final (index, object) in art.objects.indexed) {
      if (object.overhead != overhead) {
        continue;
      }
      final glyph = object.glyph;
      final corner =
          object.at ?? (glyph == null ? null : _blockCorner(grid, glyph));
      if (corner == null) {
        continue;
      }
      final name = opened ? object.whenOpen ?? object.image : object.image;
      final image = loaded.objects[name];
      if (image == null) {
        continue;
      }
      final cells = behind?[index];
      if (behind != null && (cells == null || cells.isEmpty)) {
        continue;
      }
      if (cells != null) {
        final covered = ui.Path();
        for (final (x, y) in cells) {
          covered.addRect(
            ui.Rect.fromLTWH(
              (x * loaded.manifest.tileWidth).toDouble(),
              (y * loaded.manifest.tileHeight).toDouble(),
              loaded.manifest.tileWidth.toDouble(),
              loaded.manifest.tileHeight.toDouble(),
            ),
          );
        }
        canvas
          ..save()
          ..clipPath(covered);
      }
      canvas.drawImage(
        image,
        ui.Offset(
          (corner.$1 * loaded.manifest.tileWidth).toDouble(),
          ((corner.$2 + object.offsetY) * loaded.manifest.tileHeight)
              .toDouble(),
        ),
        _paint,
      );
      if (cells != null) {
        canvas.restore();
      }
    }
  }

  /// For each object, in order, the cells where it stands in front of
  /// whoever is there: the ones someone can walk on right above a cell the
  /// object fills entirely -- its own, the airliner's hull and wings laid
  /// on their scorch -- so the top of the hull leans over the row north of
  /// it, while the shadow it throws south, or a road sign under its edge,
  /// stays where it is.
  Future<List<Set<(int, int)>>> _cellsBehindObjects(
    LoadedTileAtlas loaded,
    TilePlaceArt art,
    GlyphGrid grid,
    bool opened,
  ) async {
    final manifest = loaded.manifest;
    final tileWidth = manifest.tileWidth;
    final tileHeight = manifest.tileHeight;
    final result = <Set<(int, int)>>[];
    for (final object in art.objects) {
      final cells = <(int, int)>{};
      result.add(cells);
      final glyph = object.glyph;
      final corner =
          object.at ?? (glyph == null ? null : _blockCorner(grid, glyph));
      final name = opened ? object.whenOpen ?? object.image : object.image;
      final image = loaded.objects[name];
      if (corner == null || image == null) {
        continue;
      }
      final pixels = (await image.toByteData())!;
      final left = corner.$1;
      final top = corner.$2 + object.offsetY;
      final across = image.width ~/ tileWidth;
      final down = image.height ~/ tileHeight;
      bool filled(int cx, int cy) {
        for (var py = cy * tileHeight; py < (cy + 1) * tileHeight; py++) {
          for (var px = cx * tileWidth; px < (cx + 1) * tileWidth; px++) {
            if (pixels.getUint8((py * image.width + px) * 4 + 3) == 0) {
              return false;
            }
          }
        }
        return true;
      }

      for (var cy = 1; cy < down; cy++) {
        for (var cx = 0; cx < across; cx++) {
          final x = left + cx;
          final y = top + cy - 1;
          if (x >= 0 &&
              y >= 0 &&
              x < grid.width &&
              y < grid.height &&
              _walkable(grid, x, y) &&
              filled(cx, cy)) {
            cells.add((x, y));
          }
        }
      }
    }
    return result;
  }

  /// The top-left cell of the run of [glyph], or null if the place has
  /// none of it.
  static (int, int)? _blockCorner(GlyphGrid grid, String glyph) {
    for (var y = 0; y < grid.height; y++) {
      final x = grid.rows[y].indexOf(glyph);
      if (x >= 0) {
        var left = x;
        for (var row = y; row < grid.height; row++) {
          final found = grid.rows[row].indexOf(glyph);
          if (found >= 0 && found < left) {
            left = found;
          }
        }
        return (left, y);
      }
    }
    return null;
  }

  @override
  void render(ui.Canvas canvas) {
    final image = _opened ? _open ?? _shut : _shut;
    if (image != null && onScreen) {
      canvas.drawImage(image, offset, _paint);
    }
  }
}

/// The part of a [TilePlaceComponent] drawn over the characters (20) and
/// under the fires (25): what stands in front of whoever is behind it.
final class TilePlaceFront extends Component {
  TilePlaceFront(this.place) : super(priority: priorityOverCharacters);

  static const int priorityOverCharacters = 22;

  final TilePlaceComponent place;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  /// What is on screen, for tests and diagnostics.
  ui.Image? get image =>
      place._opened ? place._frontOpen ?? place._frontShut : place._frontShut;

  @override
  void render(ui.Canvas canvas) {
    final image = this.image;
    if (image != null && place.onScreen) {
      canvas.drawImage(image, place.offset, _paint);
    }
  }
}

/// The tiles of one layer, in the order they are drawn, sent to the canvas
/// in a single call: a city draws twenty thousand of them, and one
/// drawImageRect apiece costs more than the rest of the work together.
final class _TileBatch {
  _TileBatch(this.manifest);

  final TileAtlasManifest manifest;
  final List<double> _transforms = <double>[];
  final List<double> _rects = <double>[];

  void add(int tile, int x, int y) {
    final source = manifest.tileRect(tile);
    _transforms.addAll(<double>[
      1,
      0,
      (x * manifest.tileWidth).toDouble(),
      (y * manifest.tileHeight).toDouble(),
    ]);
    _rects.addAll(<double>[
      source.left,
      source.top,
      source.right,
      source.bottom,
    ]);
  }

  void flush(ui.Canvas canvas, ui.Image atlas, ui.Paint paint) {
    if (_rects.isEmpty) {
      return;
    }
    canvas.drawRawAtlas(
      atlas,
      Float32List.fromList(_transforms),
      Float32List.fromList(_rects),
      null,
      null,
      null,
      paint,
    );
  }
}

/// A place's images in the cache, and how many are still waiting for them.
final class _Built {
  _Built(this.images);

  final Future<(ui.Image, ui.Image)> images;
  int users = 0;
  bool _dropped = false;
  bool _disposed = false;

  /// Out of the cache: the images go once the last one waiting has its
  /// own handles.
  void drop() {
    _dropped = true;
    disposeIfDropped();
  }

  void disposeIfDropped() {
    if (!_dropped || users > 0 || _disposed) {
      return;
    }
    _disposed = true;
    images.then((images) {
      images.$1.dispose();
      images.$2.dispose();
    }).ignore();
  }
}
