# CI and Discord Social SDK Archives

This repository keeps the Discord Social SDK plaintext files out of Git. GitHub Actions restores only the encrypted archive needed by each platform job.

## Required GitHub Secrets

- `DISCORD_SDK_ANDROID_PASSPHRASE`: Android CI archive passphrase
- `DISCORD_SDK_MACOS_PASSPHRASE`: macOS CI archive passphrase
- `DISCORD_SDK_IOS_PASSPHRASE`: iOS CI archive passphrase
- `DISCORD_APPLICATION_ID`: optional Discord application ID

GitHub does not generate these passphrases automatically. The bootstrap script generates one random passphrase per platform and registers it as a repository secret.

## Platform Archives

- Android: `ci/secrets/discord-sdk-android.zip.gpg`
- macOS: `ci/secrets/discord-sdk-macos.zip.gpg`
- iOS: `ci/secrets/discord-sdk-ios.zip.gpg`

Each archive contains a different SDK file structure:

- Android: `Android/app/libs/discord_partner_sdk.aar`
- macOS: `macOS/CraftPresence/ThirdParty/DIscordSDK`
- iOS: `iOS/CraftPresence/ThirdParty/DiscordSocialSDK`

Do not create a single combined archive.

## Automatic Setup

Run the bootstrap script locally after placing the SDK files in the working tree:

```bash
./ci/scripts/bootstrap-discord-sdk-ci.sh android
./ci/scripts/bootstrap-discord-sdk-ci.sh macos
./ci/scripts/bootstrap-discord-sdk-ci.sh ios
./ci/scripts/bootstrap-discord-sdk-ci.sh all
```

The script:

- Generates a platform-specific passphrase
- Creates a platform-specific SDK zip
- Encrypts the zip with GPG AES256
- Deletes the plaintext zip
- Registers the platform-specific GitHub Secret
- Optionally registers `DISCORD_APPLICATION_ID`
- Optionally stages or commits CI files
- Optionally starts GitHub Actions workflows or lists recent runs

Examples:

```bash
./ci/scripts/bootstrap-discord-sdk-ci.sh android --repo MinePacu/CraftPresence --git-add
./ci/scripts/bootstrap-discord-sdk-ci.sh android ios --repo MinePacu/CraftPresence --git-add
./ci/scripts/bootstrap-discord-sdk-ci.sh all --repo MinePacu/CraftPresence --git-add
./ci/scripts/bootstrap-discord-sdk-ci.sh all --repo MinePacu/CraftPresence --application-id 123456789012345678 --git-add
./ci/scripts/bootstrap-discord-sdk-ci.sh all --repo MinePacu/CraftPresence --application-id 123456789012345678 --git-add --commit
./ci/scripts/bootstrap-discord-sdk-ci.sh all --repo MinePacu/CraftPresence --run-workflows --check-runs
```

Use `--allow-missing` only when intentionally bootstrapping a subset from `all`. Without it, missing SDK files fail clearly.

`--skip-gh-secrets` is restricted because generated passphrases are otherwise lost. If you use it, you must provide an external directory:

```bash
./ci/scripts/bootstrap-discord-sdk-ci.sh android --skip-gh-secrets --passphrase-output-dir "$HOME/.craftpresence-ci-secrets"
```

Keep that directory private and outside the repository.

## Manual Setup

Create a passphrase manually:

```bash
openssl rand -base64 48
```

Manual Android archive:

```bash
mkdir -p ci/secrets

zip -r ci/secrets/discord-sdk-android.zip \
  Android/app/libs/discord_partner_sdk.aar

gpg --symmetric \
  --cipher-algo AES256 \
  --output ci/secrets/discord-sdk-android.zip.gpg \
  ci/secrets/discord-sdk-android.zip

rm ci/secrets/discord-sdk-android.zip
```

Manual macOS archive:

```bash
mkdir -p ci/secrets

zip -r ci/secrets/discord-sdk-macos.zip \
  macOS/CraftPresence/ThirdParty/DIscordSDK

gpg --symmetric \
  --cipher-algo AES256 \
  --output ci/secrets/discord-sdk-macos.zip.gpg \
  ci/secrets/discord-sdk-macos.zip

rm ci/secrets/discord-sdk-macos.zip
```

Manual iOS archive:

```bash
mkdir -p ci/secrets

zip -r ci/secrets/discord-sdk-ios.zip \
  iOS/CraftPresence/ThirdParty/DiscordSocialSDK

gpg --symmetric \
  --cipher-algo AES256 \
  --output ci/secrets/discord-sdk-ios.zip.gpg \
  ci/secrets/discord-sdk-ios.zip

rm ci/secrets/discord-sdk-ios.zip
```

Register secrets with the GitHub CLI:

```bash
gh secret set DISCORD_SDK_ANDROID_PASSPHRASE
gh secret set DISCORD_SDK_MACOS_PASSPHRASE
gh secret set DISCORD_SDK_IOS_PASSPHRASE
gh secret set DISCORD_APPLICATION_ID
```

GitHub web UI location:

Settings -> Secrets and variables -> Actions -> Repository secrets -> New repository secret

## What To Commit

Commit:

- `ci/secrets/discord-sdk-android.zip.gpg`
- `ci/secrets/discord-sdk-macos.zip.gpg`
- `ci/secrets/discord-sdk-ios.zip.gpg`
- `ci/scripts/restore-discord-sdk.sh`
- `ci/scripts/bootstrap-discord-sdk-ci.sh`
- `.github/workflows/android-ci.yml`
- `.github/workflows/web-ci.yml`
- `.github/workflows/apple-ci.yml`
- `.gitignore`
- `docs/ci.md`

Do not commit:

- `ci/secrets/*.zip`
- plaintext SDK files
- passphrase files
- `local.properties`
- decrypted SDK zip files
- any other file containing secrets

## Local Restore Test

Android:

```bash
export DISCORD_SDK_ANDROID_PASSPHRASE="Android archive passphrase"
./ci/scripts/restore-discord-sdk.sh android
```

macOS:

```bash
export DISCORD_SDK_MACOS_PASSPHRASE="macOS archive passphrase"
./ci/scripts/restore-discord-sdk.sh macos
```

iOS:

```bash
export DISCORD_SDK_IOS_PASSPHRASE="iOS archive passphrase"
./ci/scripts/restore-discord-sdk.sh ios
```

## Notes

- Decrypted SDK files are used only during local restore tests or CI runs.
- Do not store SDK files in `actions/cache`.
- Do not upload SDK files as workflow artifacts.
- Do not print passphrases or `local.properties` contents in logs.
- Public fork pull requests do not receive repository secrets by default.
- The bootstrap script requires an authenticated GitHub CLI for secret registration.
- Check GitHub CLI login with `gh auth status`.
- Missing platform SDK files fail bootstrap unless `--allow-missing` is passed.
- You can bootstrap only the platforms whose SDK files are available locally.
