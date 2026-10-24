# DocuSeal SSO changelog

Versions are `<upstream DocuSeal version>-sso.<n>`. The first part is the
upstream release the fork is built on; `n` counts the fork's own releases on
top of it and starts again at 1 with each new upstream release. Each release is
tagged `v<version>` and the image is published as
`ghcr.io/deenyoro/docuseal-sso:v<version>`.

## 3.3.3-sso.1 — 2026-10-24

- Synced to upstream DocuSeal 3.3.3 (previous image was built on 3.3.2).
- Upstream changed how the settings menu hides the Console and Embedding links
  in the mobile apps. The overlay patch that hides those links
  (`0014-views-shared-_settings_nav-html-erb.patch`) no longer applied, so the
  build was failing. The patch now keeps upstream's new rule and still hides
  both links. The SSO, SMS and Plans menu changes are unchanged.
- The image now reports its version: the build writes it into `.version`,
  which upstream's own release build also does.
- Tag pipelines publish the image under the release tag and create a GitLab
  release.
