// Known-vector tests for the in-house geohash encoder.
//
// The vectors are standard-geohash values (Niemeyer / geohash.org): the
// (57.64911, 10.40744) -> 'u4pruydqqvj' example is the canonical Wikipedia
// vector. The backend has a mirror test (functions/test/geohash-compat.test.ts)
// checking the same coordinates against geofire-common, which must produce
// identical hashes for EVERY coordinate — including bisection midpoints such
// as (0, 0), where both encoders place the point in the lower half-cell
// (strict '>' comparison), yielding '7zzz…' rather than 's000…'.
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/geo/geohash.dart';

void main() {
  group('geohash encode', () {
    test('canonical Wikipedia vector (Jutland, Denmark)', () {
      // Full canonical hash is 'u4pruydqqvj'; precision 9 is its prefix.
      expect(encode(57.64911, 10.40744), 'u4pruydqq');
      expect(encode(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    });

    test('San Francisco (negative longitude)', () {
      expect(encode(37.7749, -122.4194), '9q8yyk8yt');
    });

    test('Sydney (southern hemisphere)', () {
      expect(encode(-33.8688, 151.2093), 'r3gx2f77b');
    });

    test('Rio de Janeiro (southern hemisphere and negative longitude)', () {
      expect(encode(-22.9068, -43.1729), '75cm9tfqn');
    });

    test('bisection midpoints match geofire-common (lower half-cell)', () {
      // geofire-common: geohashForLocation([0, 0], 9) == '7zzzzzzzz'.
      expect(encode(0, 0), '7zzzzzzzz');
      // geofire-common: geohashForLocation([45, 90], 9) == 'tzzzzzzzz'.
      expect(encode(45, 90), 'tzzzzzzzz');
    });

    test('domain corners match geofire-common', () {
      expect(encode(90, 180), 'zzzzzzzzz');
      expect(encode(-90, -180), '000000000');
    });

    test('precision parameter is respected', () {
      expect(encode(57.64911, 10.40744, precision: 1), 'u');
      expect(encode(57.64911, 10.40744, precision: 5), 'u4pru');
      expect(encode(57.64911, 10.40744, precision: 12), 'u4pruydqqvj8');
      for (final precision in [1, 4, 9, 12]) {
        expect(encode(48.8566, 2.3522, precision: precision).length, precision);
      }
    });

    test('default precision is 9', () {
      expect(encode(48.8566, 2.3522).length, 9);
    });

    test('rejects out-of-range input', () {
      expect(() => encode(91, 0), throwsArgumentError);
      expect(() => encode(-91, 0), throwsArgumentError);
      expect(() => encode(0, 181), throwsArgumentError);
      expect(() => encode(0, -181), throwsArgumentError);
      expect(() => encode(0, 0, precision: 0), throwsArgumentError);
      expect(() => encode(0, 0, precision: 23), throwsArgumentError);
    });
  });
}
