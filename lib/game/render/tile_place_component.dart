import 'dart:ui' as ui;

import 'package:stepbound/core/core.dart';
import 'package:stepbound/game/render/place_background.dart';
import 'package:stepbound/game/render/tile_atlas.dart';

/// Draws a place that has no baked background, tile by tile out of the
/// atlas, from the same ASCII rows the simulation walks on. Where
/// LevelBackgroundComponent shows a picture of a place, this one builds
/// the picture.
///
/// It is built once, into an image the size of the place, and drawn from
/// there: a tile loop every frame would cost a thousand draws on the
/// cheapest phone we support, and buy nothing. A place whose story can
/// open something -- the train Luigi is in -- is built twice, shut and
/// open, and the flip is then only a choice of image.
final class TilePlaceComponent extends PlaceBackground {
  TilePlaceComponent({
    required this.place,
    this.offset = ui.Offset.zero,
    this.useOpen,
  }) : super(priority: 0);

  final Place place;
  final ui.Offset offset;

  /// Whether the story has opened what this place can open.
  final bool Function()? useOpen;

  ui.Image? _shut;
  ui.Image? _open;
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  /// The name this place's art goes by in the atlas manifest.
  String get artKey => place.id.name;

  @override
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
    _shut = await _draw(loaded, art, opened: false);
    if (art.objects.any((object) => object.whenOpen != null)) {
      _open = await _draw(loaded, art, opened: true);
    }
  }

  /// Which tile of a bucket falls on a cell: a hash of its place in the
  /// grid, so the grit lies the same way at every start and there is
  /// nothing to save. tools/build_tile_atlas.py repeats this.
  static int _variant(int length, int x, int y) =>
      ((x * 73856093) ^ (y * 19349663)) % length;

  Future<ui.Image> _draw(
    LoadedTileAtlas loaded,
    TilePlaceArt art, {
    required bool opened,
  }) async {
    final manifest = loaded.manifest;
    final grid = art.gridFor(place.rows);
    final width = grid.width * manifest.tileWidth;
    final height = grid.height * manifest.tileHeight;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..color = art.voidColour,
      );
    for (final layer in <String>['ground', 'structures']) {
      _drawLayer(canvas, loaded, art, grid, layer);
    }
    _drawObjects(canvas, loaded, art, grid, opened: opened);
    for (final layer in <String>['foreground', 'overhead']) {
      _drawLayer(canvas, loaded, art, grid, layer);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  void _drawLayer(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    TilePlaceArt art,
    GlyphGrid grid,
    String layer,
  ) {
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
          _drawRule(canvas, loaded, grid, rules[next], x, y);
        }
      }
    }
  }

  void _drawRule(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    GlyphGrid grid,
    TileRule rule,
    int x,
    int y,
  ) {
    final index = rule.bucketIndex(grid, x, y);
    final bucket = rule.buckets[index];
    if (bucket.isEmpty) {
      return;
    }
    final variant = _variant(bucket.length, x, y);
    _drawTile(canvas, loaded, bucket[variant], x, y);
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
        _drawTile(canvas, loaded, tiles[variant], px, py);
      }
    }
  }

  void _drawTile(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    int tile,
    int x,
    int y,
  ) {
    final manifest = loaded.manifest;
    canvas.drawImageRect(
      loaded.atlas,
      manifest.tileRect(tile),
      ui.Rect.fromLTWH(
        (x * manifest.tileWidth).toDouble(),
        (y * manifest.tileHeight).toDouble(),
        manifest.tileWidth.toDouble(),
        manifest.tileHeight.toDouble(),
      ),
      _paint,
    );
  }

  void _drawObjects(
    ui.Canvas canvas,
    LoadedTileAtlas loaded,
    TilePlaceArt art,
    GlyphGrid grid, {
    required bool opened,
  }) {
    for (final object in art.objects) {
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
      canvas.drawImage(
        image,
        ui.Offset(
          (corner.$1 * loaded.manifest.tileWidth).toDouble(),
          ((corner.$2 + object.offsetY) * loaded.manifest.tileHeight)
              .toDouble(),
        ),
        _paint,
      );
    }
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
