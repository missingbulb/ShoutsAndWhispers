import 'cases.dart';

/// The machine-managed gallery: under every image-kind leaf in
/// `requirements.md`, an image line per golden, tagged
/// `<!-- req-gallery:<id> -->`. Prose is hand-authored; image lines are
/// derived output — regenerate (tool/build_gallery.dart), never hand-edit.
/// The gallery gate keeps the committed doc equal to this generator's
/// output, so the spec doubles as an always-current visual gallery of the
/// real product.
const String galleryMarker = '<!-- req-gallery:';

String buildGallery(
  String source, {
  required List<ScreenCase> screenCases,
  required List<SagaCase> sagaCases,
}) {
  final screenById = {for (final c in screenCases) c.id: c};
  final sagaById = {for (final c in sagaCases) c.id: c};
  final leafLine = RegExp(r'^\s*(?:-\s+)?`(\d+(?:\.\d+)+)`');

  // Drop every existing machine-managed line (plus the single blank line
  // inserted before each image block — exact inverse of the insertion below,
  // which is what makes regeneration idempotent), then re-insert fresh ones.
  final lines = <String>[];
  for (final line in source.split('\n')) {
    if (line.contains(galleryMarker)) {
      if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
      continue;
    }
    lines.add(line);
  }

  final out = <String>[];
  String? pendingId; // leaf whose bullet block we are inside
  void flush() {
    if (pendingId == null) return;
    final id = pendingId!;
    pendingId = null;
    final screen = screenById[id];
    if (screen != null) {
      final name = '${screen.slug}.${screen.id}';
      out.add('');
      out.add('  ![$name](screen/cases/$name.png) $galleryMarker$id -->');
    }
    final saga = sagaById[id];
    if (saga != null) {
      final name = '${saga.slug}.${saga.id}';
      out.add('');
      out.add(
        '  ![${saga.description}](saga/cases/$name.png) $galleryMarker$id -->',
      );
    }
  }

  for (final line in lines) {
    final match = leafLine.firstMatch(line);
    final bool continuesBullet =
        pendingId != null && match == null && line.trimLeft() != line;
    if (!continuesBullet) flush();
    out.add(line);
    if (match != null) pendingId = match.group(1);
  }
  flush();

  return out.join('\n');
}
