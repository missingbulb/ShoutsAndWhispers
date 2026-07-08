# Environments — dev now, prod at release time

The split follows the TLDR project's discipline, translated from AWS to
Firebase: **the committed default is dev, everywhere.** A plain checkout,
a local build, CI, and every deploy command in this repo talk to the dev
project. Production does not exist yet — it is created at the
firebase-release milestone — and *nothing committed here will ever point at
it*.

## The two projects

| | dev (now) | prod (at release) |
|---|---|---|
| Firebase project | `shouts-whispers-dev`¹ | `shouts-whispers-prod`¹ |
| Who talks to it | every non-release build: local `flutter run`, CI, emulators, throwaway experiments | **store-installed apps only** |
| Client config | committed in the repo (`app/lib/firebase_options.dart` after `flutterfire configure` against dev) | **never committed** — injected by the release workflow when building the store artifact |
| Android app id | `com.shoutsandwhispers.app.dev` (suffix → both installs coexist) | `com.shoutsandwhispers.app` |
| Access gate | none beyond Firebase Auth | Firebase **App Check enforced** on Firestore + Functions: Play Integrity (Android) / App Attest (iOS) — a dev build, emulator, or modified client is rejected server-side even if it holds prod config |
| Data | disposable; seedable with fake users | real users only; no seed scripts may target it |
| Deploys | `firebase deploy` (default alias = dev), auto-deployable from CI | manual, deliberate promotion only |

¹ Placeholder ids — replace with the real project ids when the projects are
created (`.firebaserc` holds the aliases).

## The contract (what keeps the split honest)

1. **Committed default = dev.** `.firebaserc`'s `default` alias is the dev
   project. There is deliberately **no `prod` alias committed** until the
   release milestone, so no command run from this repo can reach prod by
   accident — the strongest form of TLDR's "the committed default must
   never point at prod" rule.
2. **Prod config is release-pipeline-only.** Like TLDR's release workflow
   injecting the prod API URL, the store build gets its
   `firebase_options` from the release workflow's variables — a plain/local
   build physically lacks prod coordinates.
3. **Attestation beats provenance.** TLDR's guarantee is provenance-based
   (only the release pipeline is wired with prod values) — its known gap is
   that nothing server-side verifies the client. Firebase closes that gap:
   App Check enforcement on the prod project rejects requests without a
   valid Play Integrity / App Attest token, which only store-signed
   installs can mint. Dev keeps the App Check debug provider so tests and
   emulators stay friction-free.
4. **The contract gets guard tests when prod is born.** At the release
   milestone: a client test asserting the committed `firebase_options`
   projectId is the dev project (never prod — TLDR pins this exact rule in
   `client/test/inject-config.test.mjs`), and a release-workflow gate that
   fails if any injected prod variable is unset (so a dev-pointed store
   build can never ship).

## Now vs. later

**Now** (this milestone): `.firebaserc` with the dev alias; all docs and
commands assume dev; UI tests need no Firebase at all (the fake world —
see `dev/requirements/`).

**At the firebase-release milestone**: create the prod project, enable App
Check enforcement, add Android product flavors (`dev` with the `.dev`
suffix / `prod`), the release workflow with injected prod config, the guard
tests above, and store registration. That milestone is also when the
corresponding Claudinite release pack gets authored, capturing the
procedure while it is exercised for real.
