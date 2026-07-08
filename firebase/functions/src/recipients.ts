/**
 * Recipient selection — the post-filter of DESIGN.md §4 step 5.
 *
 * PURE module: no firebase imports, unit-testable without emulators.
 * (geofire-common is pure math — no firebase dependency.)
 */
import { distanceBetween } from 'geofire-common';
import { PRESENCE_TTL_MS } from './constants';

/** A presence doc that came back from the geohash-bounds candidate query. */
export interface Candidate {
  uid: string;
  lat: number;
  lng: number;
  /** Presence heartbeat time (`updatedAt`), epoch milliseconds. */
  updatedAtMs: number;
}

/** One selected recipient of a message. */
export interface Recipient {
  uid: string;
  /** How far the recipient was from the send location, rounded to whole metres. */
  distanceM: number;
  /** True on the sender's own copy. */
  isOwn: boolean;
}

/**
 * Selects the audience of a message from geohash-query candidates:
 * haversine distance <= radiusM AND fresh (updatedAtMs >= nowMs - PRESENCE_TTL_MS).
 *
 * The sender is ALWAYS included (distanceM 0, isOwn true) even if absent
 * from `candidates` or stale — senders receive their own messages
 * (DESIGN.md §1.5, §4 step 5).
 *
 * @param candidates candidate presences (geohash bounds give false positives)
 * @param center send location as [lat, lng]
 * @param radiusM delivery radius in metres
 * @param nowMs send time, epoch milliseconds
 * @param senderUid the authenticated sender's uid
 */
export function selectRecipients(
  candidates: readonly Candidate[],
  center: [number, number],
  radiusM: number,
  nowMs: number,
  senderUid: string,
): Recipient[] {
  const recipients: Recipient[] = [{ uid: senderUid, distanceM: 0, isOwn: true }];
  const freshnessCutoffMs = nowMs - PRESENCE_TTL_MS;

  for (const candidate of candidates) {
    if (candidate.uid === senderUid) {
      continue; // already included above, unconditionally
    }
    if (candidate.updatedAtMs < freshnessCutoffMs) {
      continue; // stale: "not there" as far as the system is concerned
    }
    const distanceM =
      distanceBetween([candidate.lat, candidate.lng], center) * 1000;
    if (distanceM > radiusM) {
      continue; // geohash-bound false positive outside the circle
    }
    recipients.push({
      uid: candidate.uid,
      distanceM: Math.round(distanceM),
      isOwn: false,
    });
  }

  return recipients;
}
