import '../shared/cases.dart';
import 'cases/composer.7.2.case.dart' as composer_7_2;

/// Every behavior case, registered by hand (Dart has no dynamic import);
/// the coverage gate keeps this list exactly equal to the files on disk.
final List<BehaviorCase> cases = [
  composer_7_2.theCase,
];
