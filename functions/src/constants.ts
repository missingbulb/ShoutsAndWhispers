/**
 * Single source of truth for backend constants (DESIGN.md §10).
 * Mirrored on the client in app/lib/config.dart.
 */

/** Whisper delivery radius, metres (DESIGN.md §1.3). */
export const WHISPER_RADIUS_M = 150;

/** Shout delivery radius, metres (DESIGN.md §1.3). */
export const SHOUT_RADIUS_M = 1500;

/**
 * How recently a presence heartbeat must have been reported for a user to
 * count as "known to be near" (DESIGN.md §1.2).
 */
export const PRESENCE_TTL_MS = 5 * 60 * 1000;

/** Maximum message text length after trimming (DESIGN.md §4 step 2). */
export const MAX_TEXT_LEN = 500;

/** Minimum interval between sends per user (DESIGN.md §4 step 3, §8). */
export const SEND_COOLDOWN_MS = 5000;

/** Cloud Functions deployment region. */
export const REGION = 'us-central1';
