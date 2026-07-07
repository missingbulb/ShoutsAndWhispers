/**
 * Known-vector tests for geofire-common's geohash encoder.
 *
 * These vectors are the compatibility contract with the Dart client's
 * in-house encoder (app/lib/geo/geohash.dart) — both sides must produce
 * identical geohashes or geohash range queries would miss recipients
 * (DESIGN.md §6).
 *
 * All expected values below were COMPUTED with geofire-common 6.0.0
 * (node -e '...geohashForLocation...') and the first was sanity-checked
 * against the well-known Wikipedia example:
 *   (57.64911, 10.40744) -> u4pruydqqvj  (12-char actual: u4pruydqqvj8)
 */
import { describe, expect, it } from 'vitest';
import { geohashForLocation } from 'geofire-common';

describe('geofire-common geohashForLocation known vectors', () => {
  it('encodes the Wikipedia reference point (Ejby havn, Denmark)', () => {
    const hash = geohashForLocation([57.64911, 10.40744]);
    expect(hash).toHaveLength(10); // geofire-common default precision
    expect(hash).toBe('u4pruydqqv');
    expect(hash.slice(0, 9)).toBe('u4pruydqq');
    // 12-char encoding extends the canonical Wikipedia hash 'u4pruydqqvj'.
    const hash12 = geohashForLocation([57.64911, 10.40744], 12);
    expect(hash12).toBe('u4pruydqqvj8');
    expect(hash12.startsWith('u4pruydqqvj')).toBe(true);
  });

  it('encodes San Francisco', () => {
    const hash = geohashForLocation([37.7749, -122.4194]);
    expect(hash).toBe('9q8yyk8ytp');
    expect(hash.slice(0, 9)).toBe('9q8yyk8yt');
  });

  it('encodes Sydney', () => {
    expect(geohashForLocation([-33.8688, 151.2093])).toBe('r3gx2f77bn');
  });

  it('encodes London', () => {
    expect(geohashForLocation([51.5074, -0.1278])).toBe('gcpvj0duq5');
  });

  it('encodes the origin and the domain corners', () => {
    expect(geohashForLocation([0, 0])).toBe('7zzzzzzzzz');
    expect(geohashForLocation([90, 180])).toBe('zzzzzzzzzz');
    expect(geohashForLocation([-90, -180])).toBe('0000000000');
  });

  it('matches the client encoder at the shared precision 9 (DESIGN.md §3)', () => {
    // Production presence geohashes are 9 chars on both sides: the client
    // heartbeat uses encode(..., precision: 9) and sendMessage passes 9 to
    // geohashForLocation. These vectors mirror app/test/geohash_test.dart —
    // including the bisection-midpoint cases, which both encoders place in
    // the lower half-cell (strict '>' comparison).
    expect(geohashForLocation([57.64911, 10.40744], 9)).toBe('u4pruydqq');
    expect(geohashForLocation([37.7749, -122.4194], 9)).toBe('9q8yyk8yt');
    expect(geohashForLocation([-33.8688, 151.2093], 9)).toBe('r3gx2f77b');
    expect(geohashForLocation([-22.9068, -43.1729], 9)).toBe('75cm9tfqn');
    expect(geohashForLocation([0, 0], 9)).toBe('7zzzzzzzz');
    expect(geohashForLocation([45, 90], 9)).toBe('tzzzzzzzz');
    expect(geohashForLocation([90, 180], 9)).toBe('zzzzzzzzz');
    expect(geohashForLocation([-90, -180], 9)).toBe('000000000');
  });
});
