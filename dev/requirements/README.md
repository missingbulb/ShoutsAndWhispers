# Executable UI requirements

The UI's spec, [requirements.md](requirements.md), is executable: every leaf
requirement is claimed by exactly one case that proves it against the real
app shell, driven by scripted fakes (no phone, no server, no network — see
[docs/UI-ARCHITECTURE.md](../../docs/UI-ARCHITECTURE.md)). The framework
follows the executable-requirements discipline of the
GoogleCalendarEventCreator project, ported to Flutter and extended with a
storyboard **saga** kind.

## The invariants

1. **Doc-first, red by default.** Adding a leaf to `requirements.md` fails
   the build (`test/coverage_gate_test.dart`) until a case claims it.
2. **Every leaf ⇄ exactly one case, of exactly one kind.** The gate enforces
   the bijection: leaf without case, case without leaf, double claim,
   misnamed file, or unregistered case — all red.
3. **The folder is the kind.** A case's kind is the directory it lives in
   (`screen/`, `saga/`, `behavior/`, `logic/` — registry in
   `shared/cases.dart`). Kinds are extensible: a new way of asserting
   requirements is a new folder plus a registry entry and runner.
4. **Expecteds are owner-owned.** Committed goldens (and coded assertions)
   are the owner's approval record. An agent may *propose* the expected for
   a brand-new leaf, but **never** regenerates a golden or weakens an
   assertion to turn a red requirement green — on a mismatch, surface the
   actual/expected/diff and ask.
5. **Actuals come from the shipped code.** Every case drives the real
   `ShoutsAndWhispersShell`, real screens, real formatting functions — never
   a parallel reimplementation.

## The kinds

| kind | proves | expected | runner |
|---|---|---|---|
| `screen` | a rendered resting state | one golden PNG beside the case, pixel-exact | `test/screen_requirements_test.dart` |
| `saga` | a multi-step user story | an ordered storyboard `*.step-NN.png`, pixel-exact | `test/saga_requirements_test.dart` |
| `behavior` | a driven gesture / outgoing request | coded assertions on the fakes' recordings | `test/behavior_requirements_test.dart` |
| `logic` | a pure product rule | coded `verify()` against shipped code | `test/logic_requirements_test.dart` |

A case file is `<kind>/cases/<slug>.<leaf-id>.case.dart` — snake_case slug
(named for the feature, stable across section retitles), then the dotted
leaf number. Each file exposes `final theCase = …Case(…)` and is registered
in `<kind>/manifest.dart` (Dart has no dynamic import; the gate verifies the
manifest matches the files on disk exactly). Goldens live beside their case
and are embedded into `requirements.md` by the machine-managed gallery
(`tool/build_gallery.dart`; `test/gallery_gate_test.dart` keeps it current).

## The fake world

Cases script `FakeWorld` (from the app package's `testing/` library): a
pinned clock (`2026-06-01 12:00`), scripted location/auth/backend fakes that
also record what the UI asked of them, and a deterministic tile provider so
map screenshots are byte-stable. Fonts are the real Roboto + MaterialIcons
(`shared/harness.dart` loads them; without this, goldens render blank
glyphs). Never `pumpAndSettle` — indeterminate spinners animate forever;
use the harness's fixed-duration `settle`.

## Running

```bash
cd dev/requirements
flutter pub get            # first time
flutter test               # everything: gates + all four kinds
python3 run_requirements.py     # same, robust in stall-prone sandboxes
python3 refresh_goldens.py      # regenerate goldens + gallery (see caveat!)
```

Regenerating goldens is a **product-change review step**, not a fix for red
tests — the refreshed PNGs land in the diff for the owner to approve.

## Honest gaps

Green here means the UI is faithful *given honest adapters*. The platform
boundaries themselves (real GPS/permissions, real Google sign-in, real
Firestore/Functions, push, store installability) are covered by the adapter
layer, `functions/test/`, and the deliberate v1 gaps in
[docs/DESIGN.md](../../docs/DESIGN.md) §7. A future `device` kind (real
emulator boot smoke) is the intended home for "the app actually launches on
Android" — a singleton kind, like GCEC's `heavy/`.
