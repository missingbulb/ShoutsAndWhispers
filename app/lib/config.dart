/// Client-side constants for Shouts & Whispers.
///
/// These mirror `functions/src/constants.ts` — see docs/DESIGN.md §10 for the
/// single-source-of-truth table. Keep the two files in sync.
library;

/// Whisper delivery radius in metres (the people right around you).
const int whisperRadiusM = 150;

/// Shout delivery radius in metres (the whole neighborhood).
const int shoutRadiusM = 1500;

/// Maximum message text length. The client pre-validates; the server enforces.
const int maxTextLen = 500;

/// Presence heartbeat: minimum movement (metres) that always justifies a
/// presence write, and the position-stream distance filter.
const double moveThresholdM = 25;

/// Presence heartbeat: periodic timer cadence while the app is foregrounded.
const Duration heartbeatInterval = Duration(minutes: 2);

/// Presence heartbeat: minimum gap between two presence writes unless the
/// device moved at least [moveThresholdM] metres.
const Duration minWriteGap = Duration(seconds: 30);

/// Region the callable Cloud Functions are deployed to.
const String functionsRegion = 'us-central1';
