#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# SSO Overlay — apply-patches.sh
# ---------------------------------------------------------------------------
# Applies the SSO/Enterprise patches to EXISTING upstream files at Docker
# build time.
#
# Unlike the overlay (rsync --ignore-existing) which only adds NEW files,
# these patches modify existing upstream files to wire in the SSO features:
#   - user roles (Admin/Editor/Viewer) and last-admin protection
#   - company logo settings + routes
#   - email reminder settings/UI + routes
#   - SAML SSO (gem, devise omniauth, real settings form, routes)
#   - hide the cloud-only upsell menus
#
# Each patch is a standard unified diff produced by:
#   git diff upstream/master HEAD -- <file> > sso/patches/<name>.patch
#
# If upstream changes a patched file, the patch will fail to apply and the
# build will fail loudly — this is intentional. To fix:
#   1. git merge upstream/master   (sync the fork)
#   2. Regenerate the patch:  git diff upstream/master HEAD -- <file>
#   3. Save it back into sso/patches/
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_ROOT="$(cd "${SSO_ROOT}/.." && pwd)"
PATCHES_DIR="${SSO_ROOT}/patches"

if [ ! -d "${PATCHES_DIR}" ]; then
  echo "SSO: No patches directory found, skipping"
  exit 0
fi

PATCH_COUNT=0
FAIL_COUNT=0

echo "=========================================="
echo "SSO: Applying patches"
echo "  Patches: ${PATCHES_DIR}"
echo "  Target:  ${APP_ROOT}"
echo "=========================================="

shopt -s nullglob
for patch_file in "${PATCHES_DIR}"/*.patch; do
  patch_name=$(basename "${patch_file}")

  # Idempotency: skip if the patch is already applied (e.g. a rebuilt layer).
  if patch -p1 --reverse --dry-run --directory="${APP_ROOT}" < "${patch_file}" > /dev/null 2>&1; then
    echo "SSO: Already applied, skipping: ${patch_name}"
    PATCH_COUNT=$((PATCH_COUNT + 1))
    continue
  fi

  # Dry-run first to check if the patch applies cleanly.
  if patch -p1 --dry-run --directory="${APP_ROOT}" < "${patch_file}" > /dev/null 2>&1; then
    patch -p1 --directory="${APP_ROOT}" < "${patch_file}"
    echo "SSO: Applied patch: ${patch_name}"
    PATCH_COUNT=$((PATCH_COUNT + 1))
  else
    echo "SSO: ERROR — Patch failed to apply: ${patch_name}"
    echo "SSO:   Upstream likely changed the patched file."
    echo "SSO:   Regenerate with: git diff upstream/master HEAD -- <file>"
    patch -p1 --dry-run --directory="${APP_ROOT}" < "${patch_file}" 2>&1 || true
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

if [ "${FAIL_COUNT}" -gt 0 ]; then
  echo "=========================================="
  echo "SSO: FATAL — ${FAIL_COUNT} patch(es) failed to apply!"
  echo "SSO: See errors above. Sync upstream and regenerate the patches."
  echo "=========================================="
  exit 1
fi

echo "=========================================="
echo "SSO: All ${PATCH_COUNT} patch(es) applied successfully"
echo "=========================================="
