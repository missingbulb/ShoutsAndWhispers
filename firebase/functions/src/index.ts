/**
 * Cloud Functions backend for Shouts & Whispers.
 *
 * - sendMessage (callable): the core fan-out — DESIGN.md §4 steps 1–7.
 * - cleanupPresence (scheduled): presence hygiene — DESIGN.md §4.
 */
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { initializeApp } from 'firebase-admin/app';
import {
  getFirestore,
  Timestamp,
  QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { geohashForLocation, geohashQueryBounds } from 'geofire-common';
import {
  MAX_TEXT_LEN,
  REGION,
  SEND_COOLDOWN_MS,
  SHOUT_RADIUS_M,
  WHISPER_RADIUS_M,
} from './constants';
import { Candidate, selectRecipients } from './recipients';

initializeApp();
const db = getFirestore();

/** Firestore batches allow 500 writes; stay comfortably below. */
const MAX_BATCH_WRITES = 450;

/** FCM sendEachForMulticast accepts at most 500 tokens per call. */
const MAX_MULTICAST_TOKENS = 500;

/** cleanupPresence deletes presence docs not updated for this long. */
const PRESENCE_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

function chunk<T>(items: readonly T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

/**
 * sendMessage — DESIGN.md §4.
 *
 * Request:  { text: string, kind: 'shout' | 'whisper', lat: number, lng: number }
 * Response: { messageId: string, recipientCount: number } (count excludes sender)
 */
export const sendMessage = onCall({ region: REGION }, async (request) => {
  // Step 1 — auth required; identity comes from the verified token.
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to send messages.');
  }
  const uid = request.auth.uid;
  const nameClaim = request.auth.token.name;
  const senderName =
    typeof nameClaim === 'string' && nameClaim.length > 0
      ? nameClaim
      : 'Someone';
  const pictureClaim = request.auth.token.picture;
  const senderPhotoUrl =
    typeof pictureClaim === 'string' && pictureClaim.length > 0
      ? pictureClaim
      : null;

  // Step 2 — validate input.
  const data = (request.data ?? {}) as Record<string, unknown>;
  if (typeof data.text !== 'string') {
    throw new HttpsError('invalid-argument', 'text must be a string.');
  }
  const text = data.text.trim();
  if (text.length < 1 || text.length > MAX_TEXT_LEN) {
    throw new HttpsError(
      'invalid-argument',
      `text must be 1–${MAX_TEXT_LEN} characters after trimming.`,
    );
  }
  const kind = data.kind;
  if (kind !== 'shout' && kind !== 'whisper') {
    throw new HttpsError(
      'invalid-argument',
      "kind must be 'shout' or 'whisper'.",
    );
  }
  const lat = data.lat;
  const lng = data.lng;
  if (
    typeof lat !== 'number' ||
    !Number.isFinite(lat) ||
    lat < -90 ||
    lat > 90
  ) {
    throw new HttpsError(
      'invalid-argument',
      'lat must be a finite number in [-90, 90].',
    );
  }
  if (
    typeof lng !== 'number' ||
    !Number.isFinite(lng) ||
    lng < -180 ||
    lng > 180
  ) {
    throw new HttpsError(
      'invalid-argument',
      'lng must be a finite number in [-180, 180].',
    );
  }

  const now = Timestamp.now();
  const nowMs = now.toMillis();

  // Steps 3+4 — rate limit via server-owned presence.lastSentAt, then refresh
  // sender presence (merge keeps fcmToken), stamping lastSentAt. The
  // read-check-stamp runs in a transaction so concurrent invocations from the
  // same user serialize on the presence doc: without it, N parallel calls
  // could all observe the pre-send lastSentAt, all pass the cooldown check,
  // and all fan out (DESIGN.md §8's spam mitigation would be bypassable).
  const presenceRef = db.collection('presence').doc(uid);
  // Precision 9 to match the client heartbeat and DESIGN.md §3's presence
  // field definition (geofire-common's default is 10).
  const geohash = geohashForLocation([lat, lng], 9);
  const senderPresence = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(presenceRef);
    const lastSentAt = snapshot.exists ? snapshot.get('lastSentAt') : undefined;
    if (
      lastSentAt instanceof Timestamp &&
      nowMs - lastSentAt.toMillis() < SEND_COOLDOWN_MS
    ) {
      throw new HttpsError(
        'resource-exhausted',
        'You are sending messages too quickly. Wait a few seconds.',
      );
    }
    tx.set(
      presenceRef,
      { lat, lng, geohash, updatedAt: now, lastSentAt: now },
      { merge: true },
    );
    return snapshot;
  });

  // Step 5 — find the audience: geohash bounds queries, then pure post-filter.
  //
  // NOTE: `now` was captured before these queries run, and the queries read
  // live (non-snapshot) data — a heartbeat that commits in the sub-second
  // window between the two can add or remove a candidate relative to a strict
  // reading of "the audience at time T" (DESIGN.md §1.1). Once fan-out below
  // completes the audience is genuinely fixed; the window is inherent to
  // non-snapshot reads and deliberately tolerated.
  const radiusM = kind === 'whisper' ? WHISPER_RADIUS_M : SHOUT_RADIUS_M;
  const bounds = geohashQueryBounds([lat, lng], radiusM);
  const boundSnapshots = await Promise.all(
    bounds.map(([start, end]) =>
      db
        .collection('presence')
        .orderBy('geohash')
        .startAt(start)
        .endAt(end)
        .get(),
    ),
  );
  // Bounds can overlap — dedupe candidate docs by uid.
  const presenceDocsByUid = new Map<string, QueryDocumentSnapshot>();
  for (const snapshot of boundSnapshots) {
    for (const doc of snapshot.docs) {
      presenceDocsByUid.set(doc.id, doc);
    }
  }
  const candidates: Candidate[] = [];
  for (const [candidateUid, doc] of presenceDocsByUid) {
    const candidateLat = doc.get('lat');
    const candidateLng = doc.get('lng');
    const updatedAt = doc.get('updatedAt');
    if (
      typeof candidateLat !== 'number' ||
      typeof candidateLng !== 'number' ||
      !(updatedAt instanceof Timestamp)
    ) {
      continue; // malformed presence doc — skip defensively
    }
    candidates.push({
      uid: candidateUid,
      lat: candidateLat,
      lng: candidateLng,
      updatedAtMs: updatedAt.toMillis(),
    });
  }
  const recipients = selectRecipients(
    candidates,
    [lat, lng],
    radiusM,
    nowMs,
    uid,
  );
  const recipientCount = recipients.length - 1; // excludes the sender

  // Step 6 — write the canonical message, then fan out to recipient feeds.
  const messageRef = db.collection('messages').doc();
  await messageRef.set({
    senderId: uid,
    senderName,
    senderPhotoUrl,
    text,
    kind,
    lat,
    lng,
    geohash,
    sentAt: now,
    recipientCount,
  });

  // Fan-out is at-least-once, not atomic: batches commit sequentially, so a
  // mid-fan-out crash can leave early batches delivered while the callable
  // reports failure, and a retried send mints a new messageId (duplicate feed
  // entries for the recipients already served). Accepted for v1 — see
  // DESIGN.md §7; the escape hatch is a client-supplied idempotency key.
  for (const group of chunk(recipients, MAX_BATCH_WRITES)) {
    const batch = db.batch();
    for (const recipient of group) {
      const feedRef = db
        .collection('users')
        .doc(recipient.uid)
        .collection('feed')
        .doc(messageRef.id);
      batch.set(feedRef, {
        messageId: messageRef.id,
        senderId: uid,
        senderName,
        senderPhotoUrl,
        text,
        kind,
        lat,
        lng,
        sentAt: now,
        distanceM: recipient.distanceM,
        isOwn: recipient.isOwn,
      });
    }
    await batch.commit();
  }

  // Step 7 — best-effort push. Never fails the send.
  try {
    // token -> owning uid, excluding the sender's own token.
    const tokenOwners = new Map<string, string>();
    for (const recipient of recipients) {
      if (recipient.uid === uid) {
        continue;
      }
      const token = presenceDocsByUid.get(recipient.uid)?.get('fcmToken');
      if (typeof token === 'string' && token.length > 0) {
        tokenOwners.set(token, recipient.uid);
      }
    }
    const senderToken = senderPresence.exists
      ? senderPresence.get('fcmToken')
      : undefined;
    if (typeof senderToken === 'string') {
      tokenOwners.delete(senderToken);
    }

    for (const tokens of chunk([...tokenOwners.keys()], MAX_MULTICAST_TOKENS)) {
      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title:
            kind === 'shout' ? `${senderName} shouted` : `${senderName} whispered`,
          body: text,
        },
        data: { messageId: messageRef.id, kind },
      });
      // Clear tokens FCM reports as dead so we stop pushing to them.
      const staleUids: string[] = [];
      response.responses.forEach((result, i) => {
        if (result.success) {
          return;
        }
        const code = result.error?.code;
        // firebase-admin surfaces the FCM v1 UNREGISTERED/NOT_FOUND errors as
        // 'messaging/registration-token-not-registered'. Malformed tokens come
        // back as 'messaging/invalid-argument' — safe to treat as dead here
        // because the payload is identical for every token in the multicast,
        // so a per-token invalid-argument can only mean the token itself.
        // 'messaging/invalid-registration-token' is the legacy-API spelling,
        // kept for completeness.
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-argument' ||
          code === 'messaging/invalid-registration-token'
        ) {
          const owner = tokenOwners.get(tokens[i]);
          if (owner) {
            staleUids.push(owner);
          }
        }
      });
      if (staleUids.length > 0) {
        const batch = db.batch();
        for (const staleUid of staleUids) {
          batch.set(
            db.collection('presence').doc(staleUid),
            { fcmToken: null },
            { merge: true },
          );
        }
        await batch.commit();
      }
    }
  } catch (err) {
    logger.warn('Push delivery failed (send already succeeded)', err);
  }

  return { messageId: messageRef.id, recipientCount };
});

/**
 * cleanupPresence — daily hygiene (DESIGN.md §4): deletes presence docs whose
 * updatedAt is older than 30 days. Staleness is already enforced by
 * PRESENCE_TTL at send time; this just keeps the collection small.
 */
export const cleanupPresence = onSchedule(
  { schedule: 'every 24 hours', region: REGION },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - PRESENCE_MAX_AGE_MS);
    let deleted = 0;
    for (;;) {
      const snapshot = await db
        .collection('presence')
        .where('updatedAt', '<', cutoff)
        .limit(MAX_BATCH_WRITES)
        .get();
      if (snapshot.empty) {
        break;
      }
      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      deleted += snapshot.size;
      if (snapshot.size < MAX_BATCH_WRITES) {
        break;
      }
    }
    logger.info(`cleanupPresence: deleted ${deleted} stale presence docs`);
  },
);
