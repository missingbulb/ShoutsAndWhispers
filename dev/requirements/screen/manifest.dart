import '../shared/cases.dart';
import 'cases/feed.6.2.case.dart' as feed_6_2;
import 'cases/sign_in.1.1.case.dart' as sign_in_1_1;

/// Every screen case, registered by hand (Dart has no dynamic import); the
/// coverage gate keeps this list exactly equal to the files on disk.
final List<ScreenCase> cases = [
  sign_in_1_1.theCase,
  feed_6_2.theCase,
];
