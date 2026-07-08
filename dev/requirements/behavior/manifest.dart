import '../shared/cases.dart';
import 'cases/sign_in.1.6.case.dart' as sign_in_1_6;
import 'cases/sign_in.1.7.case.dart' as sign_in_1_7;
import 'cases/auth_gate.3.1.case.dart' as auth_gate_3_1;
import 'cases/auth_gate.3.2.case.dart' as auth_gate_3_2;
import 'cases/auth_gate.3.3.case.dart' as auth_gate_3_3;
import 'cases/auth_gate.3.4.case.dart' as auth_gate_3_4;
import 'cases/map.4.3.case.dart' as map_4_3;
import 'cases/location_banner.5.4.case.dart' as location_banner_5_4;
import 'cases/location_banner.5.5.case.dart' as location_banner_5_5;
import 'cases/feed.6.9.case.dart' as feed_6_9;
import 'cases/composer.7.2.case.dart' as composer_7_2;
import 'cases/composer.7.5.case.dart' as composer_7_5;
import 'cases/composer.7.6.case.dart' as composer_7_6;
import 'cases/composer.7.7.case.dart' as composer_7_7;
import 'cases/composer.7.9.case.dart' as composer_7_9;
import 'cases/sending.8.1.case.dart' as sending_8_1;
import 'cases/sending.8.3.case.dart' as sending_8_3;
import 'cases/sending.8.4.case.dart' as sending_8_4;
import 'cases/sending.8.5.case.dart' as sending_8_5;
import 'cases/deleting.9.2.case.dart' as deleting_9_2;
import 'cases/deleting.9.3.case.dart' as deleting_9_3;

/// Every behavior case, derived from the files on disk — regenerate
/// with `dart run tool/gen_manifests.dart`; the coverage gate enforces
/// manifest ⇄ disk equality.
final List<BehaviorCase> cases = [
  sign_in_1_6.theCase,
  sign_in_1_7.theCase,
  auth_gate_3_1.theCase,
  auth_gate_3_2.theCase,
  auth_gate_3_3.theCase,
  auth_gate_3_4.theCase,
  map_4_3.theCase,
  location_banner_5_4.theCase,
  location_banner_5_5.theCase,
  feed_6_9.theCase,
  composer_7_2.theCase,
  composer_7_5.theCase,
  composer_7_6.theCase,
  composer_7_7.theCase,
  composer_7_9.theCase,
  sending_8_1.theCase,
  sending_8_3.theCase,
  sending_8_4.theCase,
  sending_8_5.theCase,
  deleting_9_2.theCase,
  deleting_9_3.theCase,
];
