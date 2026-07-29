# Shouts & Whispers — the cross-tier delivery contract

This project's own pack: the invariants that live *between* the Flutter client and the
Cloud Functions, where neither tier's compiler, analyzer, or test suite can see them. The
platform packs already own their own halves (`flutter`, `firebase`, `node`), and
`spec-driven-product` / `executable-requirements` own the loop and the spec harness — what
is left, and what is here, is the handful of agreements that break silently: no error, no
red test, just messages delivered to nobody.

The product contract these serve is [docs/DESIGN.md](../../../../docs/DESIGN.md) §1; this
file is how to keep from breaking it by accident.

## Delivery decides the audience once, and it decides it twice over

- **A geohash bounds query is a candidate query, never an answer.** `geohashQueryBounds`
  returns cells that *cover* the circle, so false positives outside the radius are
  guaranteed, not incidental. Every candidate must survive `selectRecipients` in
  `firebase/functions/src/recipients.ts` — haversine distance ≤ radius **and** fresh —
  before it becomes a recipient. Any future change that widens, caches, or short-circuits
  the query keeps the post-filter, or the radius stops meaning anything.
- **The sender is a recipient unconditionally.** `selectRecipients` seeds the list with the
  sender (`distanceM: 0`, `isOwn: true`) before it looks at a single candidate — the
  sender's own copy does not depend on their presence doc existing or being fresh
  (DESIGN.md §1.5). `recipientCount` is therefore `recipients.length - 1`, and the two
  facts move together: change one and the count reported to the sender starts lying.
- **A stale heartbeat means absent, with no fallback.** `PRESENCE_TTL_MS` is the entire
  definition of "known to be near" (DESIGN.md §1.2). A user whose last position is older
  than the cutoff is not a recipient — never "their last known position, probably still
  right". This is the mechanism behind the documented foreground-only limitation
  (DESIGN.md §7), so a fix belongs in how presence is *reported*, not in loosening the
  cutoff at selection time.

## Two encoders, one contract

The client encodes presence geohashes with a hand-rolled encoder
(`app/lib/geo/geohash.dart`, ~30 lines, no dependency); the server encodes and range-queries
with `geofire-common`. They must produce **identical** strings, including at bisection
midpoints — both use a strict `>` comparison, which puts a coordinate exactly on a midpoint
in the lower half-cell. Touching either encoder means re-running both known-vector suites
(`app/test/geohash_test.dart`, `firebase/functions/test/geohash-compat.test.ts`).

The matching *precision* is mechanical and is checked (`geohash-precision-parity`), as is
the *pairing of the vectors* the two suites carry (`geohash-vector-parity`); the matching
*encoding* is not — no scan can run one encoder against the other, which is the whole
reason the suites exist — and that is why it is stated here.

## One table, two copies

[docs/DESIGN.md](../../../../docs/DESIGN.md) §10 is the source of truth for every constant
both tiers carry; `firebase/functions/src/constants.ts` and `app/lib/config.dart` are
transcriptions of it, kept honest by the `cross-tier-constants` check. Adding a cross-tier
constant is a four-part change: the §10 row, the server copy, the client copy, and the
`PAIRS` map in the check — a value absent from `PAIRS` is a value nothing is guarding. A
constant only one tier needs (the send cooldown, the heartbeat cadence) stays out of `PAIRS`
on purpose: it cannot drift, because there is nothing to drift from.

## Running the pack's checks

```sh
node --test .claudinite/local/packs/shouts-and-whispers/pack.test.mjs
```
