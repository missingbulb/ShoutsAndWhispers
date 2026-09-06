# The dev console — scripted actors against the real backend

The app's executable requirements ([dev/requirements/](../dev/requirements/requirements.md))
prove every screen and gesture against scripted fakes: no phone, no server, no
network. Nothing in this repository exercises the other half — that a real client,
holding a real token, writing real presence, gets the delivery
[DESIGN.md §4](DESIGN.md) describes. Hyperlocal delivery cannot be observed with one
client: the whole product is *who else was near you*, and a single device is always
alone in its cell.

The dev console is that second half. It is a second client of the same backend, driving
four simulated accounts along planned paths, sending planned messages, and showing what
each of the four actually received.

## What it is

A Flutter web app at `dev/console/`, deployed to Firebase Hosting on the dev project. It
is a development instrument, not part of the product: it ships in no store, it is never
pointed at production, and the app under `app/` neither imports it nor knows it exists.

It is Flutter for one reason that outweighs the rest: it reuses this repository's
committed geohash encoder (`app/lib/geo/geohash.dart`) and message models by path
dependency rather than transcribing them a third time. A TypeScript console would add a
third copy of the encoding contract the
[shouts-and-whispers pack](../.claudinite/local/packs/shouts-and-whispers/RULES.md)
already spends two checks guarding, and would need a parallel requirements harness built
from nothing.

## The four actors

Four email/password accounts on the dev project, signed in simultaneously through four
named `FirebaseApp` instances so each holds its own auth state, its own Firestore client
and its own feed subscription. The backend sees four ordinary users; nothing about a sim
actor is privileged, and the console holds no admin credential.

Four, rather than a number, because four is what the interesting cases need: a sender, a
recipient inside the whisper radius, a recipient inside the shout radius but outside the
whisper's, and one who is out of range or stale. Every delivery rule in
[DESIGN.md §1](DESIGN.md) is expressible with those four seats.

## The plan

A plan is the console's document, and it is pure data — editable, replayable, and
shareable as JSON:

- **A path per actor**: waypoints on the map with a time offset each. Between two
  waypoints the actor moves at whatever speed the pair implies; the editor rejects a pair
  implying a speed no person walks.
- **Sends pinned along the path**: an offset, a kind (shout or whisper), and the text.
  The send happens wherever the actor is at that offset, and the console draws the
  message's origin and its radius on the map.
- **A duration** the plan runs for.

The editor is the product surface: place a path, place a send, press play, watch the four
feeds fill.

## Two run modes, and why the fast one cannot use the real backend

| | real-time | compressed |
|---|---|---|
| speed | 1× | any multiplier |
| backend | the dev project | the Firebase emulator suite |
| clock | Firestore `serverTimestamp()` | a virtual clock the console supplies |
| what it proves | the real fan-out, rules and callable work end to end | the delivery rules hold across time-dependent scenarios |

Compressed replay cannot run against a real backend, and not merely because
`PRESENCE_TTL_MS` is judged server-side against a clock no client can move. A plan
replayed at 60× *is* an actor walking at 600 km/h and sending twenty messages a second.
Those are exactly the shapes a real backend should learn to refuse — implausible speed and
implausible rate are anti-spoofing signals the product does not have yet
([DESIGN.md §7](DESIGN.md)) and will want. Teaching the dev backend to tolerate them
would spend the one environment where such a rule could be developed. So compression runs
against the emulator, where a virtual clock is honest, and the dev project only ever sees
plausible traffic.

Real-time mode against the dev project is what proves the backend works. Compressed mode
against the emulator is what makes time-dependent scenarios — presence going stale, a
cooldown expiring, a message that arrives one second too late — cheap enough to keep as
regression cases.

## Sim time: the wire contract

In compressed mode the console supplies the instant itself. Two fields carry it, both
namespaced under a single `sim` object so one predicate finds them:

- on the `sendMessage` call: `sim.now` — the virtual instant the send happens at;
- on a presence write: `sim.updatedAt` — the virtual instant the heartbeat was reported
  at, standing in for `serverTimestamp()`.

There is no third field and no bare top-level spelling. One object, one predicate, one
thing to strip.

## Why sim fields cannot reach production

A field that lets a client dictate the server's notion of *now* is the strongest
capability in this system: it defeats the cooldown, it revives stale presence, and it
backdates delivery. It exists because the emulator needs it, and four independent guards
keep it there. Each is meant to hold alone.

1. **The server admits it only under the emulator.** The gate is a runtime signal a
   deployed function cannot carry (`FUNCTIONS_EMULATOR`, which the Functions emulator sets
   and a deploy never does) — read once at module load into a single exported constant, and
   never re-derived from anything in a request. A request cannot argue its way past it,
   because nothing in the request is consulted.
2. **The edge strips it.** Outside the emulator the callable deletes the `sim` object from
   the request before a single line of handler logic reads it, and logs that it did. The
   handler is therefore written against a request shape where the field cannot exist, and
   the log is what makes a stripped request distinguishable from one that never carried the
   field — a swallowed strip is a silent capability, which is what
   [basics](../.claudinite/shared/packs/basics/RULES.md) means by code that can silently do
   nothing.
3. **Firestore rules reject it.** Presence writes carrying a client-set `updatedAt` are
   refused by the ruleset, so the capability is closed at the boundary the functions do not
   sit in front of.
4. **No product client can send it.** The app under `app/` has no code that writes a `sim`
   field, and a committed check keeps it that way — the console is the only client that
   knows the spelling.

Guards 1 and 2 are the server's; 3 is the boundary's; 4 is the client's. The
[spec-driven-product](../.claudinite/shared/packs/spec-driven-product/RULES.md) rule that
a requirement is proved at every tier that enforces it applies exactly here: this is one
requirement with four proofs, not one proof reused.

## What the console observes

Per actor: its live feed, its presence doc's freshness, and its position on the map. Per
send: the origin, the radius circle, the `recipientCount` the callable returned, and which
of the four actually received it — the matrix that makes a delivery bug visible rather
than inferable. A send whose reported count and observed recipients disagree is the
console's headline finding, because that disagreement is the one bug the app itself can
never show you.

## Its executable requirements

`dev/console/requirements/` — its own numbered spec, its own coverage gate, its own
gallery, in the shape [dev/requirements/](../dev/requirements/README.md) established. A
separate suite rather than new sections in the app's: the app's requirements document is
what the owner reads to approve *the product*, and an internal instrument's screens do not
belong in that review.

The console's own cases run against fakes like any other suite. That its real replay works
against a real backend is not something a golden can hold, and the console is itself the
instrument for observing it.

## Credentials

The console is deployed publicly on the dev project's Hosting site, so the sim accounts'
passwords are not in its bundle: the operator types them once and the browser keeps them.
A visitor who finds the URL gets an empty console and no way to sign anything in.

That is the whole protection, and it is sized to what it protects — the dev project, whose
data is disposable by [ENVIRONMENTS.md](ENVIRONMENTS.md)'s contract. It would not be
adequate for a project anyone depended on, which is a reason the console is never pointed
at one.
