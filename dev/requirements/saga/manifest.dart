import '../shared/cases.dart';
import 'cases/first_launch.11.1.case.dart' as first_launch_11_1;
import 'cases/shout_arrives.11.2.case.dart' as shout_arrives_11_2;
import 'cases/whisper_back.11.3.case.dart' as whisper_back_11_3;
import 'cases/send_time_audience.11.4.case.dart' as send_time_audience_11_4;
import 'cases/permission_trouble.11.5.case.dart' as permission_trouble_11_5;
import 'cases/prune_feed.11.6.case.dart' as prune_feed_11_6;
import 'cases/sign_out.11.7.case.dart' as sign_out_11_7;

/// Every saga case, derived from the files on disk — regenerate
/// with `dart run tool/gen_manifests.dart`; the coverage gate enforces
/// manifest ⇄ disk equality.
final List<SagaCase> cases = [
  first_launch_11_1.theCase,
  shout_arrives_11_2.theCase,
  whisper_back_11_3.theCase,
  send_time_audience_11_4.theCase,
  permission_trouble_11_5.theCase,
  prune_feed_11_6.theCase,
  sign_out_11_7.theCase,
];
