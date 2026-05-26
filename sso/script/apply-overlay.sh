#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# SSO Overlay — apply-overlay.sh
# ---------------------------------------------------------------------------
# Copies the SSO/Enterprise feature code into the DocuSeal source tree at
# Docker build time. Uses rsync --ignore-existing so upstream files are NEVER
# overwritten — new files only.
#
# Modifications to EXISTING upstream files are handled by apply-patches.sh.
# This split keeps "git merge upstream/master" conflict-free for everything
# except the handful of patched files.
#
# Called from the Dockerfile after the source is copied and before bundle/asset
# build.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERLAY_ROOT="${SSO_ROOT}/overlay"
APP_ROOT="$(cd "${SSO_ROOT}/.." && pwd)"

COLLISIONS=0

echo "=========================================="
echo "SSO: Applying overlay"
echo "  Source: ${OVERLAY_ROOT}"
echo "  Target: ${APP_ROOT}"
echo "=========================================="

check_collisions() {
  local src_dir="$1" target_dir="$2" dir_name="$3"
  while IFS= read -r -d '' file; do
    local rel_path="${file#"${src_dir}/"}"
    if [ -f "${target_dir}/${rel_path}" ]; then
      echo "SSO: ERROR — Collision: ${dir_name}/${rel_path} already exists upstream"
      echo "SSO:   Move this change into sso/patches/ as a unified diff instead."
      COLLISIONS=$((COLLISIONS + 1))
    fi
  done < <(find "${src_dir}" -type f ! -name '.gitkeep' -print0)
}

OVERLAY_DIRS="app lib config"

for dir in ${OVERLAY_DIRS}; do
  if [ -d "${OVERLAY_ROOT}/${dir}" ]; then
    file_count=$(find "${OVERLAY_ROOT}/${dir}" -type f ! -name '.gitkeep' | wc -l)
    check_collisions "${OVERLAY_ROOT}/${dir}" "${APP_ROOT}/${dir}" "${dir}"
    rsync -rv --ignore-existing --exclude='.gitkeep' "${OVERLAY_ROOT}/${dir}/" "${APP_ROOT}/${dir}/"
    echo "SSO: Overlaid ${dir}/ (${file_count} files)"
  fi
done

if [ "${COLLISIONS}" -gt 0 ]; then
  echo "=========================================="
  echo "SSO: FATAL — ${COLLISIONS} file collision(s) detected!"
  echo "SSO: Overlay files must NOT share paths with upstream DocuSeal files."
  echo "=========================================="
  exit 1
fi

echo "=========================================="
echo "SSO: Overlay applied successfully"
echo "=========================================="
