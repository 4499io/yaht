#!/bin/bash
# ci_post_xcodebuild.sh — Xcode Cloud post-action script
#
# Uploads dSYM files to Sentry after archive builds for crash symbolication.
#
# Required Xcode Cloud environment variables:
#   SENTRY_AUTH_TOKEN  — Sentry API auth token (org-level, project:write scope)
#   SENTRY_ORG        — Sentry organization slug
#   SENTRY_PROJECT    — Sentry project slug
#
# Xcode Cloud provides:
#   CI_ARCHIVE_PATH       — path to .xcarchive (dSYMs at $CI_ARCHIVE_PATH/dSYMs/)
#   CI_XCODEBUILD_ACTION  — "archive", "build-for-testing", "test", etc.

set -euo pipefail

# Only run after archive actions
if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]]; then
    echo "Not an archive action (${CI_XCODEBUILD_ACTION:-unknown}) — skipping dSYM upload."
    exit 0
fi

# Derive dSYMs path from archive path
DSYMS_PATH="${CI_ARCHIVE_PATH}/dSYMs"
if [[ -z "${CI_ARCHIVE_PATH:-}" || ! -d "${DSYMS_PATH}" ]]; then
    echo "Warning: dSYMs not found at ${DSYMS_PATH:-<unset>} — skipping upload."
    exit 0
fi

# Verify Sentry credentials.
# yaht has no Sentry SDK yet, so dSYM upload is optional: skip cleanly when
# unconfigured. Once Sentry is added, set SENTRY_AUTH_TOKEN/ORG/PROJECT in the
# Xcode Cloud workflow env and this uploads automatically.
# TODO(sentry): once the SDK is integrated, flip this back to a hard failure so
# a mis-set variable can never ship an unsymbolicated release (see 99issues).
if [[ -z "${SENTRY_AUTH_TOKEN:-}" || -z "${SENTRY_ORG:-}" || -z "${SENTRY_PROJECT:-}" ]]; then
    echo "Sentry not configured (no SDK integrated yet) — skipping dSYM upload."
    exit 0
fi

echo "Installing sentry-cli..."
brew install getsentry/tools/sentry-cli

echo "Uploading dSYMs from ${DSYMS_PATH}..."
sentry-cli debug-files upload \
    --auth-token "${SENTRY_AUTH_TOKEN}" \
    --org "${SENTRY_ORG}" \
    --project "${SENTRY_PROJECT}" \
    "${DSYMS_PATH}"

echo "dSYM upload complete."
