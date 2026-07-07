# Shouts & Whispers — Design

A hyperlocal messaging app. You send a message; the people who receive it are
the people who are physically near you **at the moment you send it**. Someone
who walks into the area a minute later never sees it. Everyone keeps a
persistent feed of every message they received, even if they weren't looking
at the app when it arrived.

## 1. Product semantics (the contract)

These rules define the product. Everything else in this document exists to
implement them.

1. **Audience is decided at send time.** A message sent at time `T` from
   location `L` is delivered to exactly the set of users whose device was
   known to be within the message's radius of `L` at time `T`. That set never
   grows afterwards.
2. **"Known to be near"** means: the user's device reported a position
   (a *presence heartbeat*) within the last `PRESENCE_TTL = 5 minutes`, and
   that position is within the radius. If your phone hasn't checked in for 5
   minutes, you are — as far as the system is concerned — not there.
3. **Two ranges** (hence the name):
   - **Whisper** — radius **150 m**. The people right around you.
   - **Shout** — radius **1,500 m**. The whole neighborhood.
4. **The feed is durable.** Delivery writes the message into each recipient's
   feed. Opening the app later shows everything you received while it was in
   your pocket. Deleting a feed entry is allowed (it's *your* copy).
5. **Senders receive their own messages** in their feed, flagged `isOwn`.
6. **Identity is real.** Every message is authenticated via the sender's
   Google identity (Firebase Auth). Display name and photo come from the
   verified auth token, not from client input.

### Explicitly out of scope for v1
- Replies / threads, likes, moderation and blocking, message expiry.
- Background location on iOS/Android (see §7 — v1 reports presence while the
  app is foregrounded).
- Anti-spoofing of GPS coordinates (fundamentally unsolvable client-side;
  see §8).

## 2. Architecture overview

```
┌─────────────── Flutter app (app/) ───────────────┐
│ Google Sign-In → Firebase Auth                    │
│ geolocator → presence heartbeat ──────────────┐   │
│ flutter_map (OSM tiles) + feed UI             │   │
│ send = callable Cloud Function ───────────┐   │   │
│ feed = Firestore stream on own subcoll.   │   │   │
└───────────────────────────────────────────┼───┼───┘
                                            ▼   ▼
┌────────────────────── Firebase ───────────────────┐
│ Auth (Google provider)                             │
│ Firestore:                                         │
│   presence/{uid}            ← heartbeats           │
│   messages/{id}             ← canonical archive    │
│   users/{uid}/feed/{id}     ← per-user inbox       │
│ Cloud Functions (Node 22, TS):                     │
│   sendMessage (callable)    ← THE core: fan-out    │
│   cleanupPresence (sched.)  ← hygiene              │
│ FCM: push to recipients                            │
└────────────────────────────────────────────────────┘
```

**Why fan-out-on-write (and not query-side geo matching):** the audience is
fixed at send time — that's the product. Materializing the audience the
moment the message is sent (writing a copy into each recipient's feed) makes
the semantic *structural*: there is no later query that could accidentally
include a late arriver, and "durable feed" falls out for free. The
alternative — storing messages with coordinates and having clients query
"messages sent where I was, when I was there" — requires keeping a location
*history* per user and doing spatio-temporal joins on read; it is more
expensive, leaks everyone's movement history into a queryable collection,
and makes the core semantic an emergent property of query correctness
instead of a fact about the data.

**Why Firebase:** Auth-with-Google, a realtime-listenable document store,
serverless functions and push notifications in one SDK; the free tier covers
development. The fan-out pattern is Firestore-idiomatic. The main
alternative considered — Postgres/PostGIS + a websocket server — gives real
geo queries and cheaper fan-out at large scale, but costs an order of
magnitude more plumbing (auth, push, offline cache, realtime) for a v1.
Revisit if/when a single shout regularly reaches >10k people (see §8).

## 3. Data model (Firestore)

### `presence/{uid}` — one doc per user, their last known position
| field       | type            | notes                                        |
|-------------|-----------------|----------------------------------------------|
| `lat`       | number          | −90..90                                      |
| `lng`       | number          | −180..180                                    |
| `geohash`   | string          | 9-char geohash of (lat,lng)                  |
| `updatedAt` | timestamp       | must equal `request.time` whenever written   |
| `fcmToken`  | string (≤ 4096 chars) \| null | current device push token      |
| `lastSentAt`| timestamp \| null | server-written; simple send rate limit     |

Written by the owning client on movement (≥ 25 m) or every 2 minutes while
foregrounded, and refreshed server-side on every send. **Not readable by any
client** — positions are visible to Cloud Functions only. This is the
privacy boundary: your location is never exposed to other users; only the
*consequence* of proximity (receiving a message) is observable.

### `messages/{messageId}` — canonical archive (no client access)
`senderId, senderName, senderPhotoUrl, text, kind ('shout'|'whisper'), lat,
lng, geohash, sentAt, recipientCount`. Exists for audit/debug/future
features; clients never read it (feeds are denormalized).

### `users/{uid}/feed/{messageId}` — the per-user inbox
| field           | type      | notes                                       |
|-----------------|-----------|---------------------------------------------|
| `messageId`     | string    | same id as `messages/{messageId}`           |
| `senderId`      | string    |                                             |
| `senderName`    | string    | from sender's verified auth token           |
| `senderPhotoUrl`| string \| null |                                        |
| `text`          | string    | ≤ 500 chars                                 |
| `kind`          | string    | `'shout'` \| `'whisper'`                    |
| `lat`, `lng`    | number    | where it was sent from (for the map)        |
| `sentAt`        | timestamp |                                             |
| `distanceM`     | number    | how far *you* were when it reached you      |
| `isOwn`         | bool      | true on the sender's own copy               |

Owner may `read` and `delete`; only Cloud Functions create. The feed stream
is `orderBy(sentAt, desc)` — single-field index, no composite needed.

## 4. The core: `sendMessage` callable function

Request: `{ text: string, kind: 'shout' | 'whisper', lat: number, lng: number }`
Response: `{ messageId: string, recipientCount: number }` (count excludes sender)

Steps (all server-side, Admin SDK):
1. **Auth required** — reject unauthenticated calls. Sender name/photo taken
   from the verified token (`name`, `picture` claims).
2. **Validate**: `text` trimmed, 1–500 chars; `kind` in enum; `lat`/`lng`
   numeric and in range.
3. **Rate limit**: reject if the sender's `presence.lastSentAt` is < 5 s ago.
4. **Refresh sender presence** with the supplied coordinates (merge — keeps
   `fcmToken`), stamping `lastSentAt`.
5. **Find the audience**: `geofire-common` → `geohashQueryBounds(center,
   radius)` → one Firestore range query per bound over
   `presence` ordered by `geohash`. Geohash bounds return false positives
   (squares overlapping the circle), so post-filter each candidate with a
   haversine `distance ≤ radius` **and** freshness `updatedAt ≥ now −
   PRESENCE_TTL`. The sender is always included (own copy, `isOwn: true`,
   `distanceM: 0`) regardless of freshness.
6. **Write**: create `messages/{id}`, then batch-write one feed doc per
   recipient (batches chunked ≤ 450 writes).
7. **Push**: FCM `sendEachForMulticast` to recipients' tokens (not the
   sender's), chunked ≤ 500, best-effort — push failure never fails the
   send. Tokens rejected as unregistered are cleared from presence.

The recipient-selection logic (step 5's post-filter) is a **pure function**
(`selectRecipients`) so it is unit-testable without emulators.

### `cleanupPresence` (scheduled, daily)
Deletes presence docs with `updatedAt` older than 30 days. Hygiene only —
staleness is already enforced by `PRESENCE_TTL` at send time.

## 5. Security rules (summary)

```
presence/{uid}:        read: never (functions only)
                       write: only owner, shape-validated; any write touching
                              position must set updatedAt == request.time
messages/{id}:         no client access
users/{uid}/feed/{id}: read, delete: owner only; create/update: never (functions only)
```

Shape validation on presence writes: numeric lat/lng in range, geohash is a
string ≤ 12 chars, fcmToken a string ≤ 4096 chars or null, no unexpected
fields, and the client may not write `lastSentAt` (server-owned). The client
upserts presence with two independent merge writes — the heartbeat
(`{lat, lng, geohash, updatedAt}`) and the token save (`{fcmToken}` alone) —
and the server's send-time refresh writes no `fcmToken` key, so the rules
validate each field *when present* on the merged document and accept either
write shape as the doc's create. `updatedAt` is pinned to `request.time`
whenever the write touches it or any positional field; an fcmToken-only
write leaves it untouched (saving a push token must not fake a heartbeat).

## 6. Client (Flutter, `app/`)

Deliberately rudimentary UI, as agreed: one sign-in screen, one home screen.

- **Map**: `flutter_map` with OpenStreetMap tiles — no API key needed, which
  keeps setup friction near zero. Shows your position and a marker per feed
  message at its send location (tap → highlight in feed).
- **Feed**: bottom panel, newest first, live `StreamBuilder` on
  `users/{me}/feed`. Shows sender, text, kind badge, relative time, and how
  far away it was sent.
- **Composer**: text field + whisper/shout toggle + send button. Send is
  disabled until a GPS fix exists.
- **Presence heartbeat** (`LocationService`): `geolocator` position stream
  with `distanceFilter: 25` m, plus a 2-minute timer tick; each fires an
  upsert of `presence/{me}`. Heartbeats are throttled to at most one write
  per 30 s unless the device moved ≥ 25 m. Geohash is computed by a small
  in-house encoder (`lib/geo/geohash.dart`, unit-tested against known
  vectors) to avoid a dependency for 30 lines of code — it must produce
  the same geohashes as `geofire-common` on the server.
- **Push** (`PushService`): requests notification permission, writes the FCM
  token into own presence doc, refreshes on token rotation. Foreground
  messages just rely on the live feed stream; background taps open the app.
- **Auth**: `google_sign_in` → Firebase Auth credential. Auth-gate widget
  swaps SignIn ↔ Home.
- **State management**: none beyond `StreamBuilder`/`StatefulWidget` +
  constructor-injected services. Adding Riverpod/Bloc to a two-screen app is
  ceremony; revisit when there's a third screen.
- `firebase_options.dart` is a committed placeholder that throws with setup
  instructions until `flutterfire configure` replaces it.

## 7. Known limitations (deliberate v1 cuts)

- **Foreground-only presence.** With the app backgrounded > 5 min, your
  presence goes stale and you stop receiving messages — you're "not there"
  in the product's eyes. Honest, but users will expect pocket delivery.
  Fast-follow: Android background location service; iOS significant-change
  monitoring (coarser, may need a larger TTL on iOS).
- **Presence heartbeats cost writes.** ~1 write/user/2 min foregrounded.
  Fine for v1 scale; at scale, move heartbeats to Realtime Database (cheaper
  ephemeral writes) and mirror to Firestore on change.
- **Fan-out write amplification.** A shout in a stadium = tens of thousands
  of feed writes from one function invocation. Acceptable well past v1; the
  escape hatch is sharding fan-out across function invocations via a task
  queue, or capping shout audience size.
- **Fan-out is at-least-once, not atomic.** Feed batches commit sequentially;
  if a commit fails mid-fan-out, earlier batches are already delivered while
  the callable reports failure, and a retried send mints a new message id —
  recipients served by the earlier batches see the message twice. Rare
  (requires sustained Firestore unavailability mid-send); the fix, if it ever
  matters, is a client-supplied idempotency key that makes the message id —
  and therefore the per-recipient feed doc ids — stable across retries.

## 8. Threat model notes

- **Location spoofing**: a client can always lie about GPS. Consequences are
  bounded: a spoofer can *receive* messages from an area they're not in, or
  *send* into one. No mitigation in v1; server-side plausibility checks
  (velocity limits between heartbeats) are the future lever.
- **Location privacy**: presence is function-read-only; feeds expose only
  the *sender's* chosen location (sending is a deliberately public act) and
  the recipient's distance-at-receipt rounded to metres — never recipient
  coordinates.
- **Spam**: 5 s per-user send cooldown server-side; content moderation out
  of scope for v1.

## 9. Repository layout

```
app/                    Flutter client (ports/adapters — UI-ARCHITECTURE.md)
functions/              Cloud Functions (TypeScript, Node 22)
dev/requirements/       executable UI requirements (spec + cases + goldens)
firestore.rules         security rules
firestore.indexes.json  (empty — single-field indexes suffice)
firebase.json           Firebase project config
.firebaserc             project aliases (committed default = dev — ENVIRONMENTS.md)
docs/                   this document, UI-ARCHITECTURE.md, ENVIRONMENTS.md
```

The UI is fully decoupled from phone and server behind injected ports
([UI-ARCHITECTURE.md](UI-ARCHITECTURE.md)), which is what makes the UI spec
executable: every §6 surface, state, and user saga is rendered and asserted
against scripted fakes in `dev/requirements/` — the spec document itself
([../dev/requirements/requirements.md](../dev/requirements/requirements.md))
embeds the rendered screenshots. Environments are dev-first
([ENVIRONMENTS.md](ENVIRONMENTS.md)): the committed default is the dev
project; production is created at the release milestone and gated by App
Check so only store-installed apps reach it.

## 10. Constants (single source of truth)

| constant          | value  | lives in                                      |
|-------------------|--------|-----------------------------------------------|
| `WHISPER_RADIUS_M`| 150    | `functions/src/constants.ts`, `app/lib/config.dart` |
| `SHOUT_RADIUS_M`  | 1500   | same                                          |
| `PRESENCE_TTL`    | 5 min  | `functions/src/constants.ts`                  |
| `MAX_TEXT_LEN`    | 500    | both (client pre-validates, server enforces)  |
| `SEND_COOLDOWN`   | 5 s    | `functions/src/constants.ts`                  |
| heartbeat cadence | 25 m / 2 min / 30 s throttle | `app/lib/config.dart`  |
