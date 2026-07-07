import '../shared/cases.dart';
import 'cases/format.10.1.case.dart' as format_10_1;

/// Every logic case, registered by hand (Dart has no dynamic import); the
/// coverage gate keeps this list exactly equal to the files on disk.
final List<LogicCase> cases = [
  format_10_1.theCase,
];
