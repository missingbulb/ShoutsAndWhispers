import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/config.dart';

import '../../shared/cases.dart';

/// The client's product constants match the spec (and mirror
/// `firebase/functions/src/constants.ts`): whisper radius 150 m, shout radius
/// 1,500 m, max message length 500.
final theCase = LogicCase(
  id: '10.9',
  slug: 'constants',
  description: 'client constants match the spec: whisper radius 150 m, '
      'shout radius 1500 m, max message length 500',
  verify: () {
    expect(whisperRadiusM, 150);
    expect(shoutRadiusM, 1500);
    expect(maxTextLen, 500);
  },
);
