import '../shared/cases.dart';
import 'cases/first_launch.11.1.case.dart' as first_launch_11_1;

/// Every saga, registered by hand (Dart has no dynamic import); the
/// coverage gate keeps this list exactly equal to the files on disk.
final List<SagaCase> cases = [
  first_launch_11_1.theCase,
];
