import '../shared/cases.dart';
import 'cases/sign_in.1.1.case.dart' as sign_in_1_1;
import 'cases/sign_in.1.2.case.dart' as sign_in_1_2;
import 'cases/sign_in.1.3.case.dart' as sign_in_1_3;
import 'cases/sign_in.1.4.case.dart' as sign_in_1_4;
import 'cases/sign_in.1.5.case.dart' as sign_in_1_5;
import 'cases/setup.2.1.case.dart' as setup_2_1;
import 'cases/map.4.1.case.dart' as map_4_1;
import 'cases/map.4.2.case.dart' as map_4_2;
import 'cases/map.4.4.case.dart' as map_4_4;
import 'cases/map.4.5.case.dart' as map_4_5;
import 'cases/map.4.6.case.dart' as map_4_6;
import 'cases/location_banner.5.1.case.dart' as location_banner_5_1;
import 'cases/location_banner.5.2.case.dart' as location_banner_5_2;
import 'cases/location_banner.5.3.case.dart' as location_banner_5_3;
import 'cases/feed.6.1.case.dart' as feed_6_1;
import 'cases/feed.6.2.case.dart' as feed_6_2;
import 'cases/feed.6.3.case.dart' as feed_6_3;
import 'cases/feed.6.4.case.dart' as feed_6_4;
import 'cases/feed.6.5.case.dart' as feed_6_5;
import 'cases/feed.6.6.case.dart' as feed_6_6;
import 'cases/feed.6.7.case.dart' as feed_6_7;
import 'cases/feed.6.8.case.dart' as feed_6_8;
import 'cases/feed.6.10.case.dart' as feed_6_10;
import 'cases/composer.7.1.case.dart' as composer_7_1;
import 'cases/composer.7.3.case.dart' as composer_7_3;
import 'cases/composer.7.4.case.dart' as composer_7_4;
import 'cases/composer.7.8.case.dart' as composer_7_8;
import 'cases/sending.8.2.case.dart' as sending_8_2;
import 'cases/deleting.9.1.case.dart' as deleting_9_1;

/// Every screen case, derived from the files on disk — regenerate
/// with `dart run tool/gen_manifests.dart`; the coverage gate enforces
/// manifest ⇄ disk equality.
final List<ScreenCase> cases = [
  sign_in_1_1.theCase,
  sign_in_1_2.theCase,
  sign_in_1_3.theCase,
  sign_in_1_4.theCase,
  sign_in_1_5.theCase,
  setup_2_1.theCase,
  map_4_1.theCase,
  map_4_2.theCase,
  map_4_4.theCase,
  map_4_5.theCase,
  map_4_6.theCase,
  location_banner_5_1.theCase,
  location_banner_5_2.theCase,
  location_banner_5_3.theCase,
  feed_6_1.theCase,
  feed_6_2.theCase,
  feed_6_3.theCase,
  feed_6_4.theCase,
  feed_6_5.theCase,
  feed_6_6.theCase,
  feed_6_7.theCase,
  feed_6_8.theCase,
  feed_6_10.theCase,
  composer_7_1.theCase,
  composer_7_3.theCase,
  composer_7_4.theCase,
  composer_7_8.theCase,
  sending_8_2.theCase,
  deleting_9_1.theCase,
];
