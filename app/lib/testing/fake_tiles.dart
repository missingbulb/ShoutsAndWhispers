/// Deterministic in-memory map tiles (docs/UI-ARCHITECTURE.md §"The fake
/// world"): a soft checkerboard with a thin grid, drawn on the fly, so map
/// screenshots are byte-stable and never touch the network or asset bundles.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tile source for tests: every tile is rendered locally by
/// [_FakeTileImage] — no HTTP, no assets, no randomness.
class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _FakeTileImage(x: coordinates.x, y: coordinates.y);
}

/// Draws one 256×256 tile with a [ui.PictureRecorder]/[ui.Canvas]: a soft
/// two-tone checkerboard keyed on `(x + y)` parity, plus a thin grid line
/// along the tile's top and left edges. Fully deterministic.
class _FakeTileImage extends ImageProvider<_FakeTileImage> {
  const _FakeTileImage({required this.x, required this.y});

  final int x;
  final int y;

  static const int _dimension = 256;

  /// Soft two-tone checkerboard colors (even / odd `(x + y)` parity).
  static const ui.Color _evenFill = ui.Color(0xFFE9EDF1);
  static const ui.Color _oddFill = ui.Color(0xFFDFE5EA);

  /// Thin grid line between tiles.
  static const ui.Color _gridLine = ui.Color(0xFFC8D0D7);

  @override
  Future<_FakeTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FakeTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _FakeTileImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: _render(key))),
    );
  }

  static ui.Image _render(_FakeTileImage key) {
    const double size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, size, size),
      ui.Paint()..color = (key.x + key.y).isEven ? _evenFill : _oddFill,
    );

    final line = ui.Paint()
      ..color = _gridLine
      ..strokeWidth = 1;
    canvas.drawLine(const ui.Offset(0, 0.5), const ui.Offset(size, 0.5), line);
    canvas.drawLine(const ui.Offset(0.5, 0), const ui.Offset(0.5, size), line);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(_dimension, _dimension);
    picture.dispose();
    return image;
  }

  @override
  bool operator ==(Object other) =>
      other is _FakeTileImage && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
