---
name: testflight
description: TestFlight distribution workflow — archive, upload, release notes, crew access
---

# /testflight

End-to-end guide for getting a DeckMate build into TestFlight and
into the hands of the crew. TestFlight is the v0.1 distribution target;
App Store submission is out of scope.

## One-time setup

1. Apple Developer Program membership (Team account).
2. In [App Store Connect](https://appstoreconnect.apple.com/):
   - Create two apps: `DeckMate` (iOS) with bundle ID `com.helmlog.deckmate.ios`,
     and `DeckMate` (Mac) with `com.helmlog.deckmate.mac`.
   - Create a TestFlight **internal tester** group (your own Apple ID).
   - Create an **external tester** group called "Crew" for the boat's
     sailors — Beta App Review will gate first submission.
3. In Xcode:
   - **Signing & Capabilities** → Team set for both app targets.
   - **Automatic signing** on for v0.1 (switch to manual later if needed).
4. Generate an **App Store Connect API key** (`AuthKey_*.p8`) for
   scripted uploads. Store under `~/.appstoreconnect/private_keys/` —
   never commit it (gitignore already blocks `AuthKey_*.p8`).

## Build + upload (per release)

1. Decide the version + build number:
   - User-visible version bumps in `Info.plist` → `CFBundleShortVersionString`.
   - `CFBundleVersion` increments monotonically, e.g. `git rev-list --count HEAD`.
2. From the repo root (the multiplatform target archives once per
   platform; watchOS has its own scheme):
   ```bash
   # iOS archive from the multiplatform scheme
   xcodebuild -project DeckMate/DeckMate.xcodeproj \
              -scheme DeckMate \
              -configuration Release \
              -destination 'generic/platform=iOS' \
              -archivePath build/DeckMate-iOS.xcarchive \
              archive

   xcodebuild -exportArchive \
              -archivePath build/DeckMate-iOS.xcarchive \
              -exportOptionsPlist DeckMate/ExportOptions.plist \
              -exportPath build/DeckMate-iOS-ipa

   # Repeat for generic/platform=macOS, generic/platform=visionOS,
   # and generic/platform=watchOS (the last uses -scheme DeckMateWatch).
   ```
3. Upload with `xcrun altool` (fallback) or preferably `xcrun notarytool`
   /`xcrun iTMSTransporter` — Xcode Organizer "Distribute App" is the
   friendlier path for learning:
   - **Window → Organizer → Archives → Distribute App → App Store Connect → Upload**
4. Wait for App Store Connect to finish processing the build (5-30 min).

## Release notes

- Draft release notes in `docs/testflight-notes/<yyyy-mm-dd>.md` before
  uploading. Include what changed, what's being tested, known issues.
- Paste the notes into the TestFlight "Test Details" field.
- If the build goes to external testers, Apple requires a short "What to
  Test" in the build's settings.

## Adding crew

1. App Store Connect → TestFlight → External Testing → Crew group →
   **Add Testers** → email address.
2. Tester accepts the invitation email, installs **TestFlight** on their
   device, then installs the HelmLog build from within TestFlight.
3. The same tester can be added to both iOS and Mac apps separately.

## Mac-specific wrinkles

- Mac builds must be **notarised** (Xcode's "Distribute App" flow
  handles this for App Store Connect uploads).
- Mac TestFlight is a relatively new feature — double-check that the
  scheme is set to "Mac" not "Mac Catalyst" unless you intend Catalyst.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Upload fails with "No suitable application records were found" | bundle ID doesn't match the App Store Connect app record |
| "Missing Compliance" in TestFlight | need to answer the encryption export question in App Store Connect |
| Build stuck in "Processing" > 1 h | check the Resolution Center in App Store Connect for a rejection |
| Internal testers can see build but external can't | external group requires Beta App Review on first submission |

## When to use this skill

- Before each TestFlight push (no matter how small).
- After bumping `CFBundleShortVersionString`.
- Whenever the upload flow fails — walk the checklist top-down.
