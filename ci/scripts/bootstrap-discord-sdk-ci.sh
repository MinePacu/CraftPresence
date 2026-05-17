#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./ci/scripts/bootstrap-discord-sdk-ci.sh [platform ...] [options]

Platforms:
  android
  macos
  ios
  all

Options:
  --repo OWNER/REPO
      GitHub repository full name. Defaults to origin remote.
  --application-id VALUE
      Also set DISCORD_APPLICATION_ID as a GitHub Actions secret.
  --skip-gh-secrets
      Do not register generated passphrases in GitHub Secrets. Requires --passphrase-output-dir.
  --passphrase-output-dir DIR
      Directory outside the repository where passphrase files are written when --skip-gh-secrets is used.
  --allow-missing
      Skip platforms whose local SDK source path is missing.
  --git-add
      Stage generated encrypted archives and CI support files.
  --commit
      Create a commit for the staged CI changes.
  --run-workflows
      Try to start relevant workflows with workflow_dispatch.
  --check-runs
      Show recent GitHub Actions runs.
  --help
      Show this help.

Examples:
  ./ci/scripts/bootstrap-discord-sdk-ci.sh android --repo MinePacu/CraftPresence --git-add
  ./ci/scripts/bootstrap-discord-sdk-ci.sh all --repo MinePacu/CraftPresence --application-id 123456789012345678 --git-add
USAGE
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

repo_from_origin() {
  local remote
  remote="$(git remote get-url origin 2>/dev/null || true)"
  [[ -n "$remote" ]] || return 1

  case "$remote" in
    git@github.com:*)
      remote="${remote#git@github.com:}"
      remote="${remote%.git}"
      ;;
    https://github.com/*)
      remote="${remote#https://github.com/}"
      remote="${remote%.git}"
      ;;
    ssh://git@github.com/*)
      remote="${remote#ssh://git@github.com/}"
      remote="${remote%.git}"
      ;;
    *)
      return 1
      ;;
  esac

  [[ "$remote" == */* ]] || return 1
  printf '%s\n' "$remote"
}

add_unique_platform() {
  local candidate="$1"
  local existing
  if ((${#platforms[@]} > 0)); then
    for existing in "${platforms[@]}"; do
      [[ "$existing" == "$candidate" ]] && return
    done
  fi
  platforms+=("$candidate")
}

source_for_platform() {
  case "$1" in
    android) printf '%s\n' "Android/app/libs/discord_partner_sdk.aar" ;;
    macos) printf '%s\n' "macOS/CraftPresence/ThirdParty/DIscordSDK" ;;
    ios) printf '%s\n' "iOS/CraftPresence/ThirdParty/DiscordSocialSDK" ;;
    *) return 1 ;;
  esac
}

archive_for_platform() {
  case "$1" in
    android) printf '%s\n' "ci/secrets/discord-sdk-android.zip" ;;
    macos) printf '%s\n' "ci/secrets/discord-sdk-macos.zip" ;;
    ios) printf '%s\n' "ci/secrets/discord-sdk-ios.zip" ;;
    *) return 1 ;;
  esac
}

secret_for_platform() {
  case "$1" in
    android) printf '%s\n' "DISCORD_SDK_ANDROID_PASSPHRASE" ;;
    macos) printf '%s\n' "DISCORD_SDK_MACOS_PASSPHRASE" ;;
    ios) printf '%s\n' "DISCORD_SDK_IOS_PASSPHRASE" ;;
    *) return 1 ;;
  esac
}

platforms=()
repo_full_name=""
application_id="${DISCORD_APPLICATION_ID:-}"
skip_gh_secrets=0
passphrase_output_dir=""
allow_missing=0
git_add=0
commit_changes=0
run_workflows=0
check_runs=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    android|macos|ios)
      add_unique_platform "$1"
      shift
      ;;
    all)
      add_unique_platform android
      add_unique_platform macos
      add_unique_platform ios
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || fail "--repo requires OWNER/REPO"
      repo_full_name="$2"
      shift 2
      ;;
    --application-id)
      [[ $# -ge 2 ]] || fail "--application-id requires a value"
      application_id="$2"
      shift 2
      ;;
    --skip-gh-secrets)
      skip_gh_secrets=1
      shift
      ;;
    --passphrase-output-dir)
      [[ $# -ge 2 ]] || fail "--passphrase-output-dir requires a directory"
      passphrase_output_dir="$2"
      shift 2
      ;;
    --allow-missing)
      allow_missing=1
      shift
      ;;
    --git-add)
      git_add=1
      shift
      ;;
    --commit)
      commit_changes=1
      git_add=1
      shift
      ;;
    --run-workflows)
      run_workflows=1
      shift
      ;;
    --check-runs)
      check_runs=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

[[ ${#platforms[@]} -gt 0 ]] || fail "choose at least one platform: android, macos, ios, or all"

require_command git
require_command zip
require_command gpg
require_command openssl

workspace="$(git rev-parse --show-toplevel)"
cd "$workspace"

if [[ -z "$repo_full_name" ]]; then
  repo_full_name="$(repo_from_origin)" || fail "could not infer GitHub repository from origin; pass --repo OWNER/REPO"
fi

if [[ "$skip_gh_secrets" -eq 1 ]]; then
  [[ -n "$passphrase_output_dir" ]] || fail "--skip-gh-secrets requires --passphrase-output-dir outside the repository so generated passphrases are not lost"
  passphrase_parent="$(dirname "$passphrase_output_dir")"
  mkdir -p "$passphrase_parent"
  passphrase_output_abs="$(cd "$passphrase_parent" && pwd)/$(basename "$passphrase_output_dir")"
  case "$passphrase_output_abs" in
    "$workspace"|"$workspace"/*)
      fail "--passphrase-output-dir must be outside the repository"
      ;;
  esac
  passphrase_output_dir="$passphrase_output_abs"
else
  require_command gh
  gh auth status >/dev/null 2>&1 || fail "gh CLI is not authenticated; run gh auth login or use --skip-gh-secrets with --passphrase-output-dir"
fi

if [[ "$run_workflows" -eq 1 || "$check_runs" -eq 1 ]]; then
  require_command gh
  gh auth status >/dev/null 2>&1 || fail "gh CLI is not authenticated; run gh auth login"
fi

mkdir -p ci/secrets

temp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

processed_platforms=()

for platform in "${platforms[@]}"; do
  source_path="$(source_for_platform "$platform")"
  zip_path="$(archive_for_platform "$platform")"
  gpg_path="$zip_path.gpg"
  secret_name="$(secret_for_platform "$platform")"

  if [[ ! -e "$source_path" ]]; then
    if [[ "$allow_missing" -eq 1 ]]; then
      info "Skipping $platform: missing SDK source path $source_path"
      continue
    fi
    fail "missing SDK source path for $platform: $source_path"
  fi

  pass_file="$temp_dir/$platform.passphrase"
  umask 077
  openssl rand -base64 48 > "$pass_file"

  info "Creating encrypted Discord SDK archive for $platform."
  rm -f "$zip_path" "$gpg_path"
  zip -q -r "$zip_path" "$source_path"

  gpg --quiet --batch --yes --pinentry-mode loopback \
    --passphrase-file "$pass_file" \
    --symmetric --cipher-algo AES256 \
    --output "$gpg_path" "$zip_path"

  rm -f "$zip_path"

  if [[ "$skip_gh_secrets" -eq 1 ]]; then
    mkdir -p "$passphrase_output_dir"
    chmod 700 "$passphrase_output_dir"
    cp "$pass_file" "$passphrase_output_dir/$secret_name.passphrase"
    chmod 600 "$passphrase_output_dir/$secret_name.passphrase"
    info "Stored $secret_name passphrase in the requested external directory. Keep it private."
  else
    gh secret set "$secret_name" --repo "$repo_full_name" < "$pass_file" >/dev/null
    info "Registered GitHub Actions secret: $secret_name"
  fi

  rm -f "$pass_file"
  processed_platforms+=("$platform")
done

if [[ ${#processed_platforms[@]} -eq 0 ]]; then
  fail "no platform archives were generated"
fi

if [[ -n "$application_id" && "$skip_gh_secrets" -eq 0 ]]; then
  printf '%s' "$application_id" | gh secret set DISCORD_APPLICATION_ID --repo "$repo_full_name" >/dev/null
  info "Registered GitHub Actions secret: DISCORD_APPLICATION_ID"
elif [[ -n "$application_id" ]]; then
  info "DISCORD_APPLICATION_ID was provided, but --skip-gh-secrets is enabled; it was not registered."
fi

if [[ "$git_add" -eq 1 ]]; then
  git add \
    ci/secrets/*.zip.gpg \
    ci/secrets/.gitkeep \
    ci/scripts/restore-discord-sdk.sh \
    ci/scripts/bootstrap-discord-sdk-ci.sh \
    .github/workflows/android-ci.yml \
    .github/workflows/web-ci.yml \
    .github/workflows/apple-ci.yml \
    .gitlab-ci.yml \
    .gitignore \
    docs/ci.md
  info "Staged generated archives and CI support files."
fi

if [[ "$commit_changes" -eq 1 ]]; then
  git commit -m "ci: add GitHub Actions workflows and encrypted Discord SDK archives"
  info "Created CI commit."
fi

if [[ "$run_workflows" -eq 1 ]]; then
  info "Trying to start workflows. If this fails, commit and push the workflow files, then run this command again."
  run_android=0
  run_apple=0
  for platform in "${processed_platforms[@]}"; do
    [[ "$platform" == "android" ]] && run_android=1
    [[ "$platform" == "macos" || "$platform" == "ios" ]] && run_apple=1
  done

  if [[ "$run_android" -eq 1 ]]; then
    gh workflow run "Android CI" --repo "$repo_full_name" || info "Could not start Android CI. Commit and push workflow files first if they are new."
  fi
  if [[ "$run_apple" -eq 1 ]]; then
    gh workflow run "Apple CI" --repo "$repo_full_name" || info "Could not start Apple CI. Commit and push workflow files first if they are new."
  fi
  if [[ ${#platforms[@]} -eq 3 ]]; then
    gh workflow run "Web CI" --repo "$repo_full_name" || info "Could not start Web CI. Commit and push workflow files first if they are new."
  fi
fi

if [[ "$check_runs" -eq 1 ]]; then
  gh run list --repo "$repo_full_name" --limit 10
fi

info "Bootstrap finished. Commit and push ci/secrets/*.zip.gpg after reviewing staged files."
