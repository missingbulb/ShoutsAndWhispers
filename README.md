# Shouts & Whispers

A hyperlocal messaging app. When you send a message, it is delivered to exactly
the people who were physically near you at the moment you sent it — a
**whisper** reaches 150 m, a **shout** reaches 1,500 m — and never to anyone
who arrives later. Every recipient keeps a durable personal feed of everything
they received, even while the app was in their pocket.

The full design (data model, fan-out architecture, security rules, threat
model) is in [docs/DESIGN.md](docs/DESIGN.md).

## Repository layout

```
app/                    Flutter client
functions/              Cloud Functions (TypeScript, Node 22)
firestore.rules         Firestore security rules
firestore.indexes.json  Firestore indexes (empty — single-field indexes suffice)
firebase.json           Firebase project config
docs/DESIGN.md          design document
```

## Prerequisites

- Flutter SDK (stable channel)
- Node 22
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- A Firebase project on the **Blaze** plan (required for Cloud Functions)
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) (`dart pub global activate flutterfire_cli`)

## Firebase setup

1. **Create a Firebase project** at <https://console.firebase.google.com>
   and upgrade it to the Blaze plan.

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

5. **Deploy the backend** (functions and Firestore rules), from the repo root:

   ```sh
   npm --prefix functions install
   firebase deploy --only functions,firestore
   ```

   The deploy's predeploy hook compiles the TypeScript automatically.

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

Cloud Functions (`functions/`):

```sh
npm run build   # tsc
npm test        # vitest — pure-function tests, no emulator needed
```

Flutter app (`app/`):

```sh
flutter analyze
flutter test
```

## Current limitations (v1)

Deliberate cuts, documented in [docs/DESIGN.md §7](docs/DESIGN.md):

- **Foreground-only presence.** If the app is backgrounded for more than
  5 minutes, your presence goes stale and you stop receiving messages —
  as far as the system is concerned, you're not there.
- **No anti-spoofing.** A client can lie about its GPS coordinates to send
  into, or receive from, an area it isn't in.
- **No moderation.** There is a 5-second server-side send cooldown, but no
  content moderation, blocking, or reporting.
