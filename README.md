# MTG Life Tracker

Flutter app (Android + iOS) for tracking life totals in Magic: The Gathering
games.

## Development

```sh
flutter pub get
flutter test
flutter run                   # needs a device/emulator
```

## Releasing to Google Play

`.github/workflows/release.yml`:

- **Push to `main`** → tests → signed app bundle → Play **internal testing**
  track.
- **Production**: Actions tab → *Deploy to Google Play* → Run workflow
  (track `production`).

Versioning is automatic: version name is `YYYY.MM.DD.<run>`, version code is
`1000 + run number`. Never rename the workflow file (it resets run numbers).

One-time setup:

1. **Upload keystore**: reuses the same upload key as scryfall-offline. To
   make a fresh one instead:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. **GitHub secrets**: `ANDROID_KEYSTORE_BASE64` (base64 of the .jks),
   `KEYSTORE_PASSWORD`, `KEY_ALIAS` (`upload`), `KEY_PASSWORD`,
   `PLAY_SERVICE_ACCOUNT_JSON` (Google Cloud service account; grant it
   release access to this app in Play Console → Users and permissions).
3. **Play Console**: create the app (package
   `com.nicksullivan.mtg_life_tracker`), enroll in Play App Signing, complete
   the store listing / data-safety / content-rating forms (see
   `store/listing.md`), and upload the **first** AAB manually through the
   Console UI (Play requires it; build one locally with
   `flutter build appbundle` + a local `android/key.properties`).
4. **GitHub Pages**: Settings → Pages → Deploy from branch → `main`, `/docs`
   (hosts the privacy policy).
5. Thereafter: push to `main`.

Local release builds: create `android/key.properties` (gitignored):

```
storeFile=upload-keystore.jks   # place the .jks in android/
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, release builds fall back to debug signing.

## Compliance

Unofficial Fan Content under the WotC Fan Content Policy. Magic: The
Gathering is ™ & © Wizards of the Coast.
