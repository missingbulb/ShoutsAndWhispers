/// A minimal standard geohash encoder.
///
/// Implements the canonical geohash algorithm (Niemeyer / geohash.org /
/// Wikipedia) with the standard base32 alphabet. It produces the same output
/// as the server's `geofire-common` `geohashForLocation` for every coordinate
/// — including bisection midpoints such as (0, 0), where geofire-common's
/// strict `>` comparison places the point in the lower half — which is what
/// keeps client heartbeats and server geo-queries speaking the same language
/// (see docs/DESIGN.md §6). Implemented by hand to avoid a dependency for
/// ~30 lines of code; unit-tested against known vectors in
/// `test/geohash_test.dart`.
library;

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Encodes [lat]/[lng] into a geohash of [precision] characters (default 9,
/// roughly a 4.8 m x 4.8 m cell).
String encode(double lat, double lng, {int precision = 9}) {
  if (lat < -90 || lat > 90) {
    throw ArgumentError.value(lat, 'lat', 'must be within [-90, 90]');
  }
  if (lng < -180 || lng > 180) {
    throw ArgumentError.value(lng, 'lng', 'must be within [-180, 180]');
  }
  if (precision < 1 || precision > 22) {
    throw ArgumentError.value(precision, 'precision', 'must be in [1, 22]');
  }

  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  var isLngBit = true; // Bits alternate, starting with longitude.
  var bitCount = 0;
  var charValue = 0;
  final hash = StringBuffer();

  while (hash.length < precision) {
    if (isLngBit) {
      final mid = (lngMin + lngMax) / 2;
      // Strictly greater-than, matching geofire-common: a coordinate exactly
      // on a bisection midpoint belongs to the LOWER half-cell.
      if (lng > mid) {
        charValue = (charValue << 1) | 1;
        lngMin = mid;
      } else {
        charValue = charValue << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat > mid) {
        charValue = (charValue << 1) | 1;
        latMin = mid;
      } else {
        charValue = charValue << 1;
        latMax = mid;
      }
    }
    isLngBit = !isLngBit;
    bitCount++;
    if (bitCount == 5) {
      hash.write(_base32[charValue]);
      bitCount = 0;
      charValue = 0;
    }
  }
  return hash.toString();
}
