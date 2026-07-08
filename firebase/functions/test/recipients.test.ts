import { describe, expect, it } from 'vitest';
import { distanceBetween } from 'geofire-common';
import { PRESENCE_TTL_MS, WHISPER_RADIUS_M } from '../src/constants';
import { Candidate, selectRecipients } from '../src/recipients';

const SENDER = 'sender-uid';
const CENTER: [number, number] = [37.7749, -122.4194];
const NOW_MS = 1_750_000_000_000;
const FRESH_MS = NOW_MS; // heartbeat right now — always fresh

// At geofire-common's earth radius (6371 km), 1 degree of latitude is
// ~111,194.93 m, so 0.001° north of center is ~111.19 m away.
const LAT_DEG_PER_M = 1 / 111_194.93;

/** A candidate `metersNorth` metres due north of CENTER. */
function north(
  uid: string,
  metersNorth: number,
  updatedAtMs: number = FRESH_MS,
): Candidate {
  return {
    uid,
    lat: CENTER[0] + metersNorth * LAT_DEG_PER_M,
    lng: CENTER[1],
    updatedAtMs,
  };
}

describe('selectRecipients', () => {
  it('returns only the sender for empty candidates', () => {
    const result = selectRecipients([], CENTER, WHISPER_RADIUS_M, NOW_MS, SENDER);
    expect(result).toEqual([{ uid: SENDER, distanceM: 0, isOwn: true }]);
  });

  it('includes a candidate just under the radius, excludes one just over', () => {
    const justUnder = north('under', WHISPER_RADIUS_M - 1); // ~149 m
    const justOver = north('over', WHISPER_RADIUS_M + 1); // ~151 m
    // Sanity-check the geometry of the fixtures themselves.
    expect(
      distanceBetween([justUnder.lat, justUnder.lng], CENTER) * 1000,
    ).toBeLessThan(WHISPER_RADIUS_M);
    expect(
      distanceBetween([justOver.lat, justOver.lng], CENTER) * 1000,
    ).toBeGreaterThan(WHISPER_RADIUS_M);

    const result = selectRecipients(
      [justUnder, justOver],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    const uids = result.map((r) => r.uid);
    expect(uids).toContain('under');
    expect(uids).not.toContain('over');
  });

  it('includes a candidate exactly at the freshness cutoff, excludes 1 ms staler', () => {
    const cutoffMs = NOW_MS - PRESENCE_TTL_MS;
    const justFresh = north('fresh', 10, cutoffMs); // updatedAtMs >= cutoff
    const justStale = north('stale', 10, cutoffMs - 1);

    const result = selectRecipients(
      [justFresh, justStale],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    const uids = result.map((r) => r.uid);
    expect(uids).toContain('fresh');
    expect(uids).not.toContain('stale');
  });

  it('always includes the sender when absent from candidates', () => {
    const result = selectRecipients(
      [north('other', 10)],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    expect(result).toContainEqual({ uid: SENDER, distanceM: 0, isOwn: true });
  });

  it('includes the sender exactly once even when present and stale', () => {
    const stalePresence: Candidate = {
      uid: SENDER,
      lat: CENTER[0],
      lng: CENTER[1],
      updatedAtMs: NOW_MS - PRESENCE_TTL_MS - 60_000, // long stale
    };
    const result = selectRecipients(
      [stalePresence],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    const senderEntries = result.filter((r) => r.uid === SENDER);
    expect(senderEntries).toEqual([{ uid: SENDER, distanceM: 0, isOwn: true }]);
  });

  it('gives the sender distanceM 0 and isOwn true even when far from center', () => {
    const farSender = north(SENDER, 5000); // candidate doc far outside radius
    const result = selectRecipients(
      [farSender],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    expect(result).toEqual([{ uid: SENDER, distanceM: 0, isOwn: true }]);
  });

  it('marks non-sender recipients isOwn false', () => {
    const result = selectRecipients(
      [north('neighbor', 20)],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    const neighbor = result.find((r) => r.uid === 'neighbor');
    expect(neighbor).toBeDefined();
    expect(neighbor!.isOwn).toBe(false);
  });

  it('rounds distanceM to whole metres', () => {
    // 0.001° of latitude ≈ 111.19 m with geofire's 6371 km earth radius.
    const candidate: Candidate = {
      uid: 'metric',
      lat: CENTER[0] + 0.001,
      lng: CENTER[1],
      updatedAtMs: FRESH_MS,
    };
    const exactM =
      distanceBetween([candidate.lat, candidate.lng], CENTER) * 1000;
    expect(Number.isInteger(exactM)).toBe(false); // fixture really is fractional

    const result = selectRecipients(
      [candidate],
      CENTER,
      WHISPER_RADIUS_M,
      NOW_MS,
      SENDER,
    );
    const metric = result.find((r) => r.uid === 'metric');
    expect(metric).toBeDefined();
    expect(metric!.distanceM).toBe(Math.round(exactM));
    expect(metric!.distanceM).toBe(111);
    expect(Number.isInteger(metric!.distanceM)).toBe(true);
  });
});
