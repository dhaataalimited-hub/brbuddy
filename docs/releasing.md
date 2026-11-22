# Releasing BRBuddy

A release is a signed, notarized `BRBuddy-<version>.dmg` on GitHub Releases, plus `appcast.xml` (the Sparkle update
feed that installed copies check) and a Homebrew cask. Pushing a `vX.Y.Z` tag does it all in GitHub Actions
(`.github/workflows/release.yml`, which runs `Tools/release.sh`).

## One-time setup (the maintainer does this; keep every key private)

### 1. Developer ID certificate
Distribution outside the App Store needs a **Developer ID Application** certificate (an *Apple Development*
certificate isn't enough). Only the team's Account Holder can create one.

1. Xcode → Settings → Accounts → select the team → **Manage Certificates…** → **+** → **Developer ID Application**.
2. Keychain Access → My Certificates → right-click "Developer ID Application: …" → **Export…** → save as
   `DeveloperID.p12` with a strong password.

### 2. Notarization key
App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → **+** (access: Developer).
Download `AuthKey_<KEYID>.p8` (it can only be downloaded once) and note the **Key ID** and **Issuer ID**.

### 3. Sparkle update keys
Sparkle signs every update; installed copies only accept updates signed with this key. **Back up the private key:
lose it and existing users can never be updated again.**

```bash
Tools/release-tools.sh
```

That links Sparkle's tools into `build/sparkle-tools`, from the copy SwiftPM downloaded and checksum-verified with
the Sparkle dependency. Then create the key pair (the private key goes into your
login keychain and the public key is printed):

```bash
build/sparkle-tools/bin/generate_keys
```

Export the private key to a file for GitHub, and keep a copy in your password manager:

```bash
build/sparkle-tools/bin/generate_keys -x sparkle-private-key.txt
```

### 4. GitHub secrets and variables
Run these yourself from the folder holding the files (each `gh secret set` without `<` asks you to paste the value):

```bash
base64 -i DeveloperID.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --repo dhaataalimited-hub/brbuddy
```

```bash
gh secret set DEVELOPER_ID_P12_PASSWORD --repo dhaataalimited-hub/brbuddy
```

```bash
base64 -i AuthKey_KEYID.p8 | gh secret set NOTARY_KEY_P8_BASE64 --repo dhaataalimited-hub/brbuddy
```

```bash
gh secret set NOTARY_KEY_ID --repo dhaataalimited-hub/brbuddy
```

```bash
gh secret set NOTARY_ISSUER_ID --repo dhaataalimited-hub/brbuddy
```

```bash
gh secret set SPARKLE_PRIVATE_KEY --repo dhaataalimited-hub/brbuddy < sparkle-private-key.txt
```

The public key isn't secret; store it as a variable:

```bash
gh variable set SPARKLE_PUBLIC_KEY --repo dhaataalimited-hub/brbuddy --body "PASTE_PUBLIC_KEY"
```

Then delete `DeveloperID.p12`, `AuthKey_*.p8` and `sparkle-private-key.txt` from disk (after backing them up).

### 5. Make the repository public
Downloads, the update feed and Homebrew all need public release files.

## Each release

1. Update `ROADMAP.md`/`README.md` if needed and merge to `main`.
2. Tag and push:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

3. Watch the **Release** workflow in GitHub Actions. It tests, builds a universal app, signs it (hardened runtime),
   notarizes and staples the app and then the DMG, signs the appcast, and publishes the release. The job runs in the
   `release` environment, so it **waits for your approval** first: open the run and click **Review deployments →
   Approve**. The signing secrets live in that environment, which only `v*` tags can use.
4. Homebrew: download the `brbuddy-cask` artifact from the workflow run and commit it as `Casks/brbuddy.rb` in the
   `dhaataalimited-hub/homebrew-tap` repository. Users then install with `brew install dhaataalimited-hub/tap/brbuddy`.
   (homebrew/cask itself accepts the app once the repo is 30+ days old with 75+ stars, or 225+ if we submit it.)

## App icon
`Config/AppIcon.icns` is drawn by the app itself (`AppIconArt`, option "2-brb-bubble"). To change it, edit
`AppIconArt`, then in a debug build:

```bash
BRBUDDY_ICON_OPTIONS=/tmp/icons .build/debug/BRBuddy
```

Quit it, keep the chosen 1024 px PNG as `Config/AppIcon-1024.png`, and rebuild the `.icns` from it (sizes 16 to 1024
with `sips`, then `iconutil -c icns`).

## Releasing from a Mac instead of CI

With the certificate in your keychain, notary credentials saved once
(`xcrun notarytool store-credentials brbuddy-notary --key AuthKey_KEYID.p8 --key-id KEYID --issuer ISSUERID`)
and the Sparkle private key in your keychain:

```bash
SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" SPARKLE_PUBLIC_KEY="PUBLIC_KEY" NOTARY_PROFILE=brbuddy-notary Tools/release.sh 0.1.0
```

Then upload `build/release/BRBuddy-0.1.0.dmg` and `build/release/appcast.xml` to a GitHub release named `v0.1.0`.

## Dry run (no certificate needed)

```bash
SIGN_IDENTITY=- SPARKLE_PUBLIC_KEY=dry-run SKIP_NOTARIZE=1 Tools/release.sh 0.1.0
```

Builds everything ad-hoc signed and unnotarized into `build/release/` to check the pipeline.
