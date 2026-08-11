#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# SSO Overlay Verifier — verify-overlay.sh
# ---------------------------------------------------------------------------
# The build's last line of defence. Runs AFTER apply-overlay.sh + apply-patches.sh
# (in the same hermetic step), on the fully-assembled tree that is about to be
# baked into the image.
#
# heal-patches.sh can re-anchor a drifted patch via a fuzzy apply, then
# regenerate an "exact" patch from the result. If that fuzzy apply lands a hunk
# in the wrong place — or drops it — the regenerated patch looks clean and passes
# `git apply --check`, but an SSO feature is silently gone. That is what made
# destroy_settings_sso_index_path disappear in production.
#
# This script asserts every SSO/SMS feature's critical marker actually survived
# into the built tree. Any miss => exit 1 => the image is NOT shipped.
#
# Pure bash + grep so it runs in the alpine toolbox alongside patch/rsync.
# Assertions live in sso/overlay-assertions.txt (format: <file>::<substring>).
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_ROOT="$(cd "${SSO_ROOT}/.." && pwd)"
ASSERTIONS="${SSO_ROOT}/overlay-assertions.txt"

cd "${APP_ROOT}"

if [ ! -f "${ASSERTIONS}" ]; then
  echo "SSO VERIFY: FATAL — assertions file not found: ${ASSERTIONS}"
  exit 2
fi

echo "=========================================="
echo "SSO: Verifying overlay/patches survived apply"
echo "  Assertions: ${ASSERTIONS}"
echo "=========================================="

missing=0
checked=0
while IFS= read -r line || [ -n "${line}" ]; do
  # skip blanks and comments
  case "${line}" in '' | \#*) continue ;; esac
  file="${line%%::*}"
  sub="${line#*::}"
  checked=$((checked + 1))

  if [ ! -f "${file}" ]; then
    echo "SSO: ✗ MISSING FILE    ${file}   (marker: ${sub})"
    missing=$((missing + 1))
    continue
  fi
  # -F: fixed string (markers contain regex metachars like ? and '); -q: quiet.
  if grep -qF -- "${sub}" "${file}"; then
    echo "SSO: ✓ ${file} :: ${sub}"
  else
    echo "SSO: ✗ MISSING MARKER  ${file} :: ${sub}"
    missing=$((missing + 1))
  fi
done < "${ASSERTIONS}"

echo "------------------------------------------"
if [ "${missing}" -gt 0 ]; then
  echo "SSO: FATAL — ${missing}/${checked} assertion(s) failed."
  echo "SSO: An SSO/SMS change did NOT survive apply — a patch drifted and healed"
  echo "SSO: wrong, or a hunk was silently dropped. DO NOT SHIP THIS IMAGE."
  echo "SSO: Re-anchor the offending patch (see sso/README.md) and rebuild."
  echo "=========================================="
  exit 1
fi

echo "SSO: ✓ All ${checked} assertions present — overlay/patches intact."
echo "=========================================="
