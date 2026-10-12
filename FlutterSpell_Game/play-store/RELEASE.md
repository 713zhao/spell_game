# Releasing AI Spell Game to Google Play

Already in place: applicationId `com.aispell.game`, release signing via `android/key.properties` + `android/upload-keystore.jks` (both git-ignored — **back them up**; losing the upload key means a reset request to Google).

## 1. One-time machine setup (this machine has Android SDK but no JDK)
```
sudo apt install openjdk-17-jdk
flutter doctor --android-licenses
```

## 2. Version
`pubspec.yaml` has `version: 1.0.0+1` → `name+versionCode`. Bump the `+N` for every upload.

## 3. Build the bundle
```
cd FlutterSpell_Game
flutter build appbundle --release --dart-define=API_BASE_URL=https://spellbackend.fly.dev
# output: build/app/outputs/bundle/release/app-release.aab
```
Confirm it's signed with the upload key: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`

## 4. Play Console (https://play.google.com/console) — manual, needs your developer account
1. Create app → name "AI Spell Game", English, App, Free. (Personal developer accounts created after Nov 2023 must run a **closed test with 12+ testers for 14 days** before production access.)
2. Set up: privacy policy URL, App access, Ads, Content rating, Target audience, Data safety, Government/Financial declarations — answers in `data-safety.md`.
3. Store listing: text and URLs from `store-listing.md`; upload icon, feature graphic, screenshots.
4. Testing → Closed testing → Create release → upload the `.aab`, accept Play App Signing, paste release notes → roll out; add testers.
5. After the testing requirement is met: Production → Create release → submit for review (typically a few days).

## 5. Optional: automate uploads later
Create a service account in Play Console (Setup → API access), download its JSON key (keep out of git), and use `fastlane supply` or the Play Developer API to upload the `.aab`. The very first upload of a new app must be done in the console.
