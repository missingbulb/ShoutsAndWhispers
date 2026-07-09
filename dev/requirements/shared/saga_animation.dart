/// Recording a saga as a single animated PNG (APNG) golden.
///
/// A saga's expected is one committed `saga/cases/<slug>.<id>.png` — a
/// *lossless* animated PNG that records the real UI as it moves between the
/// story's steps (spinners, dialog fades, snackbar slides, feed inserts, map
/// recenters), not a slideshow of resting states. See the design in
/// dev/requirements/requirements.md §11 and the tracking issue.
///
/// Four concerns live here:
///
/// 1. **Capture** — grab the outermost `RepaintBoundary` (the same one the
///    still-golden path uses) to raw RGBA once per pumped frame, via
///    `toImage` inside [WidgetTester.runAsync] (reading image bytes is real
///    async work the fake-async test zone won't otherwise complete).
/// 2. **Shorten delays** — time is virtual here, so a scripted wait is a run
///    of *identical* frames. Consecutive identical frames are collapsed and
///    any single hold is clamped ([_maxHold]); genuine animation (frames that
///    differ) survives. This keeps the animation, not the waiting.
/// 3. **Encode** — assemble the kept frames into one APNG with `package:image`
///    (lossless RGBA — no palette, quantization, or dithering to make
///    deterministic, unlike GIF).
/// 4. **Compare** — the assertion is *exact byte identity* of the encoded
///    APNG (simplest possible check, and the strictness we want given a
///    deterministic pipeline). On a mismatch, decode both and write a
///    per-frame `expected | actual | diff` artifact under `failures/`.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Capture resolution for saga animations. Deliberately 1.0 (not the stills'
/// 3.0): APNG is lossless, so a lower DPR costs no fidelity beyond scale while
/// cutting per-frame rasterize/encode cost and committed file size ~9×. The
/// single biggest lever keeping full generation affordable on every run.
const double sagaAnimationDpr = 1.0;

/// Frame cadence while recording a step's animation (~30 fps). Fine for UI
/// motion and half the frames of 60 fps.
const Duration _frameGap = Duration(milliseconds: 33);

/// Hard cap on frames captured per step — bounds indeterminate animations
/// (the app's `CircularProgressIndicator`s never settle) so a spinner
/// contributes a few rotation frames, not an unbounded reel. 20 × 33 ms ≈
/// 0.66 s, comfortably past Material's ~300 ms transitions.
const int _maxFramesPerStep = 20;

/// Stop a step early once this many consecutive frames are identical — the
/// UI has settled, so further pumping is dead time we skip (perf + shorten).
const int _settleFrames = 2;

/// Ceiling on any single held (static) frame. A long virtual wait collapses
/// to one frame shown this long instead of a dead span.
const Duration _maxHold = Duration(milliseconds: 500);

/// A settled step's final frame is held at least this long so a reader can
/// take in the resting state before the story moves on.
const Duration _restHold = Duration(milliseconds: 700);

/// One retained animation frame: tightly-copied RGBA pixels plus how long to
/// display it.
class _Frame {
  _Frame(this.bytes, this.width, this.height, this.hold);

  final Uint8List bytes;
  final int width;
  final int height;
  Duration hold;
}

/// Records a saga's frames, shortens delays, and encodes/compares the APNG.
/// One instance per saga run.
class SagaRecorder {
  SagaRecorder({this.dpr = sagaAnimationDpr, this.region});

  final double dpr;

  /// Optional sub-region to record instead of the whole app (e.g. just the
  /// top `AppBar`). Any [Finder] matching exactly one widget works — the full
  /// frame is captured and cropped to the finder's rect, so the target needs
  /// no `RepaintBoundary` of its own. Null records the whole app.
  final Finder? region;

  final List<_Frame> _frames = <_Frame>[];
  Rect? _regionLogical;

  /// Captures the opening resting state as the first frame.
  Future<void> open(WidgetTester tester) async {
    await _capture(tester, _restHold, _restHold);
  }

  /// Runs [act], then records the resulting animation frame-by-frame until it
  /// settles (or the per-step cap), and holds the settled frame for reading.
  Future<void> step(
    WidgetTester tester,
    Future<void> Function() act,
  ) async {
    await act();
    var stable = 0;
    for (var i = 0; i < _maxFramesPerStep; i++) {
      await tester.pump(_frameGap);
      final changed = await _capture(tester, _frameGap, _maxHold);
      if (changed) {
        stable = 0;
      } else if (++stable >= _settleFrames) {
        break;
      }
    }
    _rest();
  }

  /// Encodes the retained frames into one animated PNG (APNG). Deterministic
  /// given identical pixels: no palette or dithering, fixed compression.
  Uint8List encode() {
    img.Image? anim;
    for (final f in _frames) {
      final frame = img.Image.fromBytes(
        width: f.width,
        height: f.height,
        bytes: f.bytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
        frameDuration: f.hold.inMilliseconds,
      );
      if (anim == null) {
        anim = frame;
      } else {
        anim.addFrame(frame);
      }
    }
    return img.encodePng(anim!);
  }

  /// Asserts the encoded APNG against the committed golden by *exact identity*
  /// — or, with `flutter test --update-goldens`, writes the golden (the path
  /// `refresh_goldens.py` drives). On a mismatch, writes a per-frame diff
  /// artifact and fails.
  Future<void> compareOrUpdate(WidgetTester tester, String slugId) async {
    final actual = encode();
    final path = 'saga/cases/$slugId.png';
    final file = File(path);

    if (autoUpdateGoldenFiles) {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(actual);
      return;
    }
    if (!file.existsSync()) {
      fail('Missing saga animation golden: $path\n'
          'Regenerate (owner-approved) with: python3 refresh_goldens.py');
    }
    final expected = file.readAsBytesSync();
    if (_bytesEqual(actual, expected)) return;

    final report = _writeDiff(slugId, expected, actual);
    fail('Saga animation `$slugId` differs from its committed golden.\n'
        '$report'
        'If this change is intended, regenerate (owner-approved) with: '
        'python3 refresh_goldens.py');
  }

  // --- capture ------------------------------------------------------------

  /// Captures one frame; appends it, or (if identical to the previous frame)
  /// extends that frame's hold up to [maxHold]. Returns whether the pixels
  /// changed.
  Future<bool> _capture(
    WidgetTester tester,
    Duration gap,
    Duration maxHold,
  ) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    // Reading image bytes is real async work; the fake-async test zone only
    // completes it inside runAsync. toImage after a pump has a composited
    // layer to snapshot.
    final captured = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: dpr);
      try {
        final bd = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        // Tight copy so `.buffer` is exactly these pixels (offset 0).
        return (
          Uint8List.fromList(bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes)),
          image.width,
          image.height,
        );
      } finally {
        image.dispose();
      }
    });
    final (rawBytes, fullWidth, fullHeight) = captured!;
    Uint8List bytes = rawBytes;
    int width = fullWidth;
    int height = fullHeight;

    if (region != null) {
      _regionLogical ??= tester.getRect(region!);
      final r = _regionLogical!;
      // `int.clamp` is typed `num`, hence the `.toInt()`.
      final x = (r.left * dpr).round().clamp(0, fullWidth).toInt();
      final y = (r.top * dpr).round().clamp(0, fullHeight).toInt();
      final cw = (r.width * dpr).round().clamp(1, fullWidth - x).toInt();
      final ch = (r.height * dpr).round().clamp(1, fullHeight - y).toInt();
      bytes = _cropRgba(rawBytes, fullWidth, x, y, cw, ch);
      width = cw;
      height = ch;
    }

    if (_frames.isNotEmpty && _bytesEqual(_frames.last.bytes, bytes)) {
      final extended = _frames.last.hold + gap;
      _frames.last.hold = extended > maxHold ? maxHold : extended;
      return false;
    }
    _frames.add(_Frame(bytes, width, height, gap));
    return true;
  }

  /// Holds the most recent (settled) frame long enough to read.
  void _rest() {
    if (_frames.isEmpty) return;
    final f = _frames.last;
    if (f.hold < _restHold) f.hold = _restHold;
  }

  // --- diff artifact (failure path only) ----------------------------------

  String _writeDiff(String slugId, Uint8List expected, Uint8List actual) {
    Directory('failures').createSync(recursive: true);
    File('failures/$slugId.expected.png').writeAsBytesSync(expected);
    File('failures/$slugId.actual.png').writeAsBytesSync(actual);

    final exp = img.decodePng(expected);
    final act = img.decodePng(actual);
    if (exp == null || act == null) {
      return '  wrote failures/$slugId.actual.png '
          '(could not decode for a frame diff)\n';
    }

    final expFrames = exp.frames;
    final actFrames = act.frames;
    final overlap =
        expFrames.length < actFrames.length ? expFrames.length : actFrames.length;
    final differing = <int>[];
    img.Image? diffAnim;
    for (var i = 0; i < overlap; i++) {
      final (panel, changed) = _triptych(expFrames[i], actFrames[i]);
      if (changed) differing.add(i);
      panel.frameDuration = 500;
      if (diffAnim == null) {
        diffAnim = panel;
      } else {
        diffAnim.addFrame(panel);
      }
    }
    if (diffAnim != null) {
      File('failures/$slugId.diff.png').writeAsBytesSync(img.encodePng(diffAnim));
    }

    return '  frames — expected: ${expFrames.length}, actual: ${actFrames.length}\n'
        '  differing frames: ${differing.isEmpty ? '(none within overlap — frame count/timing differs)' : differing.join(', ')}\n'
        '  wrote failures/$slugId.diff.png (expected | actual | diff)\n';
  }

  /// Builds one `expected | actual | diff` panel; changed pixels are painted
  /// magenta over a dimmed base so a localized UI change reads as a localized
  /// highlight.
  (img.Image, bool) _triptych(img.Image e, img.Image a) {
    final w = e.width;
    final h = e.height;
    final out = img.Image(width: w * 3, height: h, numChannels: 4);
    var changed = false;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pe = e.getPixel(x, y);
        final pa = (x < a.width && y < a.height) ? a.getPixel(x, y) : pe;
        out.setPixelRgba(x, y, pe.r, pe.g, pe.b, pe.a);
        out.setPixelRgba(w + x, y, pa.r, pa.g, pa.b, pa.a);
        final same =
            pe.r == pa.r && pe.g == pa.g && pe.b == pa.b && pe.a == pa.a;
        if (same) {
          out.setPixelRgba(
              2 * w + x, y, pe.r * 0.25, pe.g * 0.25, pe.b * 0.25, 255);
        } else {
          changed = true;
          out.setPixelRgba(2 * w + x, y, 255, 0, 255, 255);
        }
      }
    }
    return (out, changed);
  }
}

/// Crops raw RGBA [src] (a [srcWidth]-wide image) to the rectangle
/// (`x`,`y`,`cw`×`ch`), row by row.
Uint8List _cropRgba(
  Uint8List src,
  int srcWidth,
  int x,
  int y,
  int cw,
  int ch,
) {
  final out = Uint8List(cw * ch * 4);
  for (var row = 0; row < ch; row++) {
    final srcStart = ((y + row) * srcWidth + x) * 4;
    out.setRange(row * cw * 4, (row + 1) * cw * 4, src, srcStart);
  }
  return out;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
