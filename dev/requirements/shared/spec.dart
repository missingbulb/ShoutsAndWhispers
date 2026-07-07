import 'dart:io';

/// Parser for `requirements.md` — the numbered prose spec.
///
/// A requirement line starts (optionally after a list dash) with a
/// backtick-wrapped dotted number: `` `4.2` ``. A **leaf** is a requirement
/// with no finer-numbered child (`5.6` is not a leaf if `5.6.1` exists).
/// Mirrors the GoogleCalendarEventCreator framework's parser so the two
/// projects' specs stay drop-in compatible.
final RegExp _reqLine = RegExp(r'^\s*(?:-\s+)?`(\d+(?:\.\d+)+)`');

/// All requirement ids in [specFile], in document order.
List<String> allRequirementIds(File specFile) {
  final ids = <String>[];
  for (final line in specFile.readAsLinesSync()) {
    final match = _reqLine.firstMatch(line);
    if (match != null) ids.add(match.group(1)!);
  }
  return ids;
}

/// The leaf requirement ids of [specFile] — every id with no finer child.
List<String> leafRequirementIds(File specFile) {
  final ids = allRequirementIds(specFile);
  return ids
      .where((id) => !ids.any((other) => other != id && other.startsWith('$id.')))
      .toList(growable: false);
}

/// Repository-relative location of the spec, resolved from this package's
/// root (the directory `flutter test` runs in).
File specFile() => File('requirements.md');
