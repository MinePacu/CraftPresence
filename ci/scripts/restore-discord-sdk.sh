#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./ci/scripts/restore-discord-sdk.sh android
  ./ci/scripts/restore-discord-sdk.sh macos
  ./ci/scripts/restore-discord-sdk.sh ios
USAGE
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

platform="$1"
case "$platform" in
  android)
    archive_rel="ci/secrets/discord-sdk-android.zip.gpg"
    passphrase_env="DISCORD_SDK_ANDROID_PASSPHRASE"
    verify_rel="Android/app/libs/discord_partner_sdk.aar"
    ;;
  macos)
    archive_rel="ci/secrets/discord-sdk-macos.zip.gpg"
    passphrase_env="DISCORD_SDK_MACOS_PASSPHRASE"
    verify_rel="macOS/CraftPresence/ThirdParty/DIscordSDK"
    ;;
  ios)
    archive_rel="ci/secrets/discord-sdk-ios.zip.gpg"
    passphrase_env="DISCORD_SDK_IOS_PASSPHRASE"
    verify_rel="iOS/CraftPresence/ThirdParty/DiscordSocialSDK"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  workspace="$GITHUB_WORKSPACE"
else
  workspace="$(git rev-parse --show-toplevel)"
fi

archive_path="$workspace/$archive_rel"
verify_path="$workspace/$verify_rel"

[[ -f "$archive_path" ]] || fail "missing encrypted Discord SDK archive: $archive_rel"

passphrase="${!passphrase_env:-}"
[[ -n "$passphrase" ]] || fail "missing required environment variable: $passphrase_env"

temp_dir=""
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  temp_dir="$(mktemp -d "$RUNNER_TEMP/discord-sdk-restore.XXXXXX")"
else
  temp_dir="$(mktemp -d)"
fi

zip_path="$temp_dir/discord-sdk-$platform.zip"
pass_file="$temp_dir/passphrase"

cleanup() {
  rm -f "$zip_path" "$pass_file"
  [[ -n "$temp_dir" ]] && rm -rf "$temp_dir"
}
trap cleanup EXIT

umask 077
printf '%s' "$passphrase" > "$pass_file"

gpg --quiet --batch --yes --pinentry-mode loopback \
  --passphrase-file "$pass_file" \
  --output "$zip_path" \
  --decrypt "$archive_path" || fail "failed to decrypt Discord SDK archive for $platform"

unzip -q -o "$zip_path" -d "$workspace" || fail "failed to unzip Discord SDK archive for $platform"

[[ -e "$verify_path" ]] || fail "Discord SDK restore completed, but expected path is missing: $verify_rel"

printf 'Discord SDK archive restored for %s.\n' "$platform"
