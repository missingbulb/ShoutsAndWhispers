# shouts-and-whispers pack (local)

This repo's own pack: the **cross-tier delivery contract** between the Flutter client
(`app/`) and the Cloud Functions (`firebase/functions/`) — the agreements neither tier's
compiler, analyzer, or test suite can see, and that fail silently when broken (no error, no
red test, just messages delivered to nobody).

Declared by hand as `local/shouts-and-whispers` in `.claudinite-checks.json`; never
fingerprinted (`detect`/`marker` are null). It deliberately holds nothing the canon already
homes: `flutter`, `firebase`, `node`, `android`, `ios` own their platforms,
`spec-driven-product` and `executable-requirements` own the loop and the spec harness.

## Checks

| Rule (≤5 words) | Severity | What |
|---|---|---|
| Cross-tier constants agree | blocking | the constants both tiers carry hold the same value, and match `docs/DESIGN.md` §10 |
| Geohash precision matches | blocking | client heartbeat and `sendMessage` encode presence geohashes at the same precision |
| Sender excluded from count | blocking | the sender seeded into the recipient list is the sender subtracted from the reported `recipientCount` |

All three carry a staleness guard: if a guarded declaration or call site is renamed or moved
out of the scanned tree, the check says so instead of quietly passing.

`cross-tier-constants` is deliberately *not* the canon `shared-constants` guard: that one
byte-counts a declared literal per file, which here collides on substrings (`150` inside
`1500`), cannot express the paired identifiers (`WHISPER_RADIUS_M` / `whisperRadiusM`), and
only covers values someone remembered to declare. Pairing by name needs no per-value upkeep.

## Prose (`RULES.md`) — by section

| Section (≤5 words) | How enforced |
|---|---|
| Delivery decides the audience twice | prose (candidate query + post-filter, stale means absent) + the `sender-recipient-count-parity` check |
| Two encoders, one contract | prose + the `geohash-precision-parity` check (+ both tiers' known-vector suites) |
| One table, two copies | prose + the `cross-tier-constants` check |

## Fixtures

```sh
node --test .claudinite/local/packs/shouts-and-whispers/pack.test.mjs
```

Seventeen cases: each check red on a violating fixture, quiet on a clean one, red on its
staleness case, and quiet when run against the real repo tree (so a check that stops
matching the project's actual files fails here instead of passing vacuously).

Distilled from this repo's own code and design: `docs/DESIGN.md` §1/§3/§10,
`firebase/functions/src/{constants,index,recipients}.ts`, `app/lib/{config,geo/geohash}.dart`,
`app/lib/adapters/geolocator_location_adapter.dart`, and the paired known-vector suites
`app/test/geohash_test.dart` / `firebase/functions/test/geohash-compat.test.ts`.
