# DocuSeal SSO changelog

Versions are `<upstream DocuSeal version>-sso.<n>`. The first part is the
upstream release the fork is built on; `n` counts the fork's own releases on
top of it and starts again at 1 with each new upstream release. Each release is
tagged `v<version>` and the image is published as
`ghcr.io/deenyoro/docuseal-sso:v<version>`.

## 3.3.3-sso.3 — 2026-10-28

- SSO: a SAML response can only be used to sign in once. Accepted assertion
  IDs are stored (new `saml_assertion_uses` table, created automatically at
  start-up) until the assertion expires, and a re-posted response is refused.
  Sign-in started from Authentik (app tiles) still works.
- SSO: after Single Logout, DocuSeal no longer redirects to whatever address
  the `RelayState` parameter names. Only DocuSeal's own pages and the IdP
  logout URL's host are allowed; anything else goes to the home page.
- Force SSO: invitation links no longer let a new user set a password and sign
  in with it. They send the user to the sign-in page, where SSO signs them in.
- SMS: the RingCentral server URL must be an `https://*.ringcentral.com`
  address, so the RingCentral credentials cannot be sent to another server.
- The overlay script now also copies `sso/overlay/db/` (for the new table).

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
