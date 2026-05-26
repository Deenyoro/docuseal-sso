# DocuSeal SSO ← Authentik (SAML)

Step-by-step to wire DocuSeal's SAML SSO to an Authentik SAML provider. DocuSeal
is the **Service Provider (SP)**; Authentik is the **Identity Provider (IdP)**.

## Security baseline (already enforced by this overlay)
- `ruby-saml >= 1.18.0` / `omniauth-saml >= 2.2.1` are pinned — the fix for the
  CVE-2025-25291/25292 SAML auth-bypass.
- An **IdP signing certificate is required** to save SSO settings, so every SAML
  response is signature-verified (no cert ⇒ no validation ⇒ forgeable).
- The OmniAuth request phase is CSRF-protected (`omniauth-rails_csrf_protection`).
- JIT-provisioned users default to a **non-admin** role and only when you opt in.

## 1. In DocuSeal — read the SP values
Sign in as an admin → **Settings → SSO**. The page shows:
- **ACS URL** — `https://<your-docuseal-host>/auth/saml/callback`
- **Entity ID** — `https://<your-docuseal-host>/auth/saml/metadata`
- **Metadata** — `https://<your-docuseal-host>/auth/saml/metadata`

## 2. In Authentik — create the SAML provider + application
1. **Providers → Create → SAML Provider.**
2. **ACS URL** = the DocuSeal **ACS URL** above.
3. **Issuer** (Authentik's entity ID) = leave the Authentik default, or set your own — **note it down**, you'll paste it into DocuSeal as the IdP entity ID.
4. **Audience** = the DocuSeal **Entity ID** above.
5. **Service Provider Binding** = `Post`.
6. **Signing Certificate** = pick (or let Authentik generate) a certificate — this is the cert DocuSeal verifies against.
7. **NameID Property Mapping**: optional. Authentik's default NameID is a *persistent hashed ID*, which DocuSeal does **not** use for matching — DocuSeal matches users by the **email attribute** (handled automatically). If you prefer, set NameID to the user's email; DocuSeal will use that too.
8. Create an **Application** bound to this provider so users are authorized.

Authentik's endpoints for this provider (slug = your app slug):
- SSO URL: `https://<authentik-host>/application/saml/<slug>/sso/binding/redirect/`
- Metadata: `https://<authentik-host>/application/saml/<slug>/metadata/`

## 3. In DocuSeal — fill in the SSO form
- **Identity Provider SSO URL** = Authentik's SSO URL (step 2 endpoints).
- **Identity Provider X.509 certificate** = download the signing cert from the
  Authentik provider and paste the PEM (`-----BEGIN CERTIFICATE----- …`).
- **Identity Provider entity ID** = Authentik's **Issuer** (step 2.3). Setting this
  makes DocuSeal also validate the assertion issuer (recommended).
- **Email attribute** = leave blank. Authentik sends
  `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` by default,
  which DocuSeal already matches. Only fill this if you customized the mapping.
- Optionally enable **auto-provision** + pick a default role for first-time users.
- Save. A **Sign in with SSO** button now appears on the login page.

## 4. Test
Open the login page in a private window → **Sign in with SSO** → authenticate at
Authentik → you should land back in DocuSeal signed in. If a user doesn't exist
and auto-provision is off, create them first (matched by email).

## Troubleshooting
- **"could not be found"** after login → the email attribute didn't arrive. Confirm
  the Authentik provider sends the email claim (default mapping does), or set the
  **Email attribute** field to your mapping's SAML attribute name.
- **Signature/validation errors** → the pasted cert doesn't match Authentik's
  *signing* certificate, or the clock skew exceeds 30s. Re-copy the signing cert.
- **Redirect/ACS mismatch** → the ACS URL in Authentik must exactly equal the one
  DocuSeal shows (host/scheme included). Set DocuSeal's `APP_URL`/`HOST` to the
  public URL so the ACS URL is correct.
