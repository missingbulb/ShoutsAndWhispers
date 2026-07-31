# Shouts & Whispers

<!-- claudinite:packs -->
![spec-driven-product](../../../../../tmp/claudinite-canon-qJKyyO/packs/spec-driven-product/badge.svg "spec-driven-product") ![executable-requirements](../../../../../tmp/claudinite-canon-qJKyyO/packs/executable-requirements/badge.svg "executable-requirements") ![flutter](../../../../../tmp/claudinite-canon-qJKyyO/packs/flutter/badge.svg "flutter") ![android](../../../../../tmp/claudinite-canon-qJKyyO/packs/android/badge.svg "android") ![ios](../../../../../tmp/claudinite-canon-qJKyyO/packs/ios/badge.svg "ios") ![firebase](../../../../../tmp/claudinite-canon-qJKyyO/packs/firebase/badge.svg "firebase") ![node](../../../../../tmp/claudinite-canon-qJKyyO/packs/node/badge.svg "node") ![basics](../../../../../tmp/claudinite-canon-qJKyyO/packs/basics/badge.svg "basics") ![barriers](../../../../../tmp/claudinite-canon-qJKyyO/packs/barriers/badge.svg "barriers") ![git-github](../../../../../tmp/claudinite-canon-qJKyyO/packs/git-github/badge.svg "git-github") ![tidy-repo](../../../../../tmp/claudinite-canon-qJKyyO/packs/tidy-repo/badge.svg "tidy-repo") ![grow_with_claudinite](../../../../../tmp/claudinite-canon-qJKyyO/packs/grow_with_claudinite/badge.svg "grow_with_claudinite")<!-- /claudinite:packs -->

A hyperlocal messaging app. When you send a message, it is delivered to exactly
the people who were physically near you at the moment you sent it — a
**whisper** reaches 150 m, a **shout** reaches 1,500 m — and never to anyone
who arrives later. Every recipient keeps a durable personal feed of everything
they received, even while the app was in their pocket.

The full design (data model, fan-out architecture, security rules, threat
model) is in [docs/DESIGN.md](docs/DESIGN.md). The UI's
dependency-injection architecture is
[docs/UI-ARCHITECTURE.md](docs/UI-ARCHITECTURE.md); the dev/prod
environment plan is [docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md).

## Repository layout

```
app/                    Flutter client (ports/adapters — see docs/UI-ARCHITECTURE.md)
firebase/               Firebase project root (everything the Firebase CLI reads)
  firebase.json         Firebase project config
  .firebaserc           project aliases (committed default = dev, always)
  firestore.rules       Firestore security rules
  firestore.indexes.json  Firestore indexes (empty — single-field indexes suffice)
  functions/            Cloud Functions (TypeScript, Node 22)
dev/requirements/       executable UI requirements: spec, cases, goldens, runners
docs/                   design, UI architecture, environments
```

## Prerequisites

- Flutter SDK (stable channel)
- Node 22
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- A Firebase project on the **Blaze** plan (required for Cloud Functions)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) (`dart pub global activate flutterfire_cli`)

## Firebase setup

Everything below targets the **dev** project — the committed default in
`.firebaserc`. Production doesn't exist yet and nothing in this repo will
ever point at it by accident; the plan for the split (and why only
store-installed apps will talk to prod) is
[docs/ENVIRONMENTS.md](docs/ENVIRONMENTS.md).

1. **Create the dev Firebase project** at
   <https://console.firebase.google.com> (suggested id:
   `shouts-whispers-dev` — update `firebase/.firebaserc` if you pick another) and
   upgrade it to the Blaze plan.

2. **Enable Google sign-in**: in the console, Authentication → Sign-in
   method → add **Google** as a provider.

3. **Configure the Flutter app**:

   ```sh
   cd app
   flutterfire configure
   ```

   This generates `lib/firebase_options.dart` (replacing the committed
   placeholder, which throws with setup instructions until you do this) and
   the platform config files (`google-services.json` /
   `GoogleService-Info.plist`).

4. **Android only — register your SHA-1 fingerprint** (required for Google
   Sign-In). Get the debug-keystore fingerprint with:

   ```sh
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android
   ```

   Add the SHA-1 under Project settings → Your apps → Android app in the
   Firebase console, then re-download `google-services.json` (or re-run
   `flutterfire configure`).

5. **Deploy the backend** (functions and Firestore rules), from the
   `firebase/` project root:

   ```sh
   cd firebase
   npm --prefix functions install
   firebase deploy --only functions,firestore
   ```

   The deploy's predeploy hook compiles the TypeScript automatically. (The
   Firebase CLI locates the project by the `firebase.json` in `firebase/`;
   from elsewhere in the repo, pass `--config firebase/firebase.json`.)

## Run the app

```sh
cd app
flutter pub get
flutter run
```

The app asks for location permission on first launch — it needs a GPS fix
before you can send, and it reports presence heartbeats while foregrounded.
The map uses OpenStreetMap tiles, so no maps API key is needed.

## Development

Cloud Functions (`firebase/functions/`):

```sh
cd firebase/functions
npm run build   # tsc
npm test        # vitest — pure-function tests, no emulator needed
```

Flutter app (`app/`):

```sh
flutter analyze
flutter test
```

Executable UI requirements (`dev/requirements/` — the UI spec run as tests;
see its [README](dev/requirements/README.md)):

```sh
cd dev/requirements
flutter pub get                # first time
flutter test                   # coverage gate + screens + sagas + behaviors + logic
python3 refresh_goldens.py     # regenerate goldens + gallery (review step!)
```

Every screen state, gesture, and multi-step user saga renders and asserts
against scripted fakes — no device, no Firebase project, no network. The
spec ([dev/requirements/requirements.md](dev/requirements/requirements.md))
embeds the rendered screenshots inline, so reading it is reviewing the app.

## Current limitations (v1)

Deliberate cuts, documented in [docs/DESIGN.md §7](docs/DESIGN.md):

- **Foreground-only presence.** If the app is backgrounded for more than
  5 minutes, your presence goes stale and you stop receiving messages —
  as far as the system is concerned, you're not there.
- **No anti-spoofing.** A client can lie about its GPS coordinates to send
  into, or receive from, an area it isn't in.
- **No moderation.** There is a 5-second server-side send cooldown, but no
  content moderation, blocking, or reporting.
