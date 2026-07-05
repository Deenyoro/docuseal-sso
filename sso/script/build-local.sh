#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# SSO Overlay — build-local.sh
# ---------------------------------------------------------------------------
# Builds the DocuSeal SSO image locally, exactly like CI does:
#   1. Stage a clean copy of the working tree (committed state via git
#      archive, so a dirty checkout can't leak into the image).
#   2. Apply the SSO overlay + patches to the staged copy.
#   3. Build with UPSTREAM's own Dockerfile — never a forked copy, so
#      upstream build changes are always honored.
#
#   sso/script/build-local.sh [image-tag]        # default: docuseal-sso:local
# ---------------------------------------------------------------------------

TAG="${1:-docuseal-sso:local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGE_DIR}"' EXIT

echo "SSO: Staging clean tree -> ${STAGE_DIR}"
git -C "${REPO_ROOT}" archive HEAD | tar -x -C "${STAGE_DIR}"

echo "SSO: Applying overlay + patches"
docker run --rm -v "${STAGE_DIR}:/src" -w /src alpine:3 \
  sh -c 'apk add -q --no-cache bash patch rsync findutils \
         && bash sso/script/apply-overlay.sh \
         && bash sso/script/apply-patches.sh'

echo "SSO: Building ${TAG} with upstream Dockerfile"
docker build -f "${STAGE_DIR}/Dockerfile" -t "${TAG}" "${STAGE_DIR}"

echo "SSO: Built ${TAG}"
