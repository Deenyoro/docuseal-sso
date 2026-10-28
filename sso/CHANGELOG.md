# DocuSeal SSO changelog

Versions are `<upstream DocuSeal version>-sso.<n>`. The first part is the
upstream release the fork is built on; `n` counts the fork's own releases on
top of it and starts again at 1 with each new upstream release. Each release is
tagged `v<version>` and the image is published as
`ghcr.io/deenyoro/docuseal-sso:v<version>`.

## 3.3.3-sso.2 — 2026-10-28

- Email reminders: when two reminder times passed between hourly checks (for
  example after downtime), only the later reminder was sent, but the earlier
  one then went out an hour later, after it. An earlier reminder is now
  treated as covered once a later one has been sent.
- Email reminders: a reminder that was still queued or retrying when the next
  hourly check ran could be queued again and emailed twice. Each reminder is
  now sent at most once per signer.

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
