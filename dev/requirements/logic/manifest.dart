import '../shared/cases.dart';
import 'cases/format.10.1.case.dart' as format_10_1;
import 'cases/format.10.2.case.dart' as format_10_2;
import 'cases/format.10.3.case.dart' as format_10_3;
import 'cases/format.10.4.case.dart' as format_10_4;
import 'cases/format.10.5.case.dart' as format_10_5;
import 'cases/format.10.6.case.dart' as format_10_6;
import 'cases/format.10.7.case.dart' as format_10_7;
import 'cases/wire.10.8.case.dart' as wire_10_8;
import 'cases/constants.10.9.case.dart' as constants_10_9;

/// Every logic case, derived from the files on disk — regenerate
/// with `dart run tool/gen_manifests.dart`; the coverage gate enforces
/// manifest ⇄ disk equality.
final List<LogicCase> cases = [
  format_10_1.theCase,
  format_10_2.theCase,
  format_10_3.theCase,
  format_10_4.theCase,
  format_10_5.theCase,
  format_10_6.theCase,
  format_10_7.theCase,
  wire_10_8.theCase,
  constants_10_9.theCase,
];
