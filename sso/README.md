# SSO Overlay

Adds DocuSeal **Pro/Enterprise features without a paid license** on top of the
pristine upstream tree, applied at Docker build time so the fork syncs cleanly.

Modelled on the `kc/` overlay pattern from `zammad-kc` and the `sso/` overlay in
`Stirling-PDF-SSO`.

## What's included

Feature code ported from
[docuseal-plus](https://github.com/SpeedbitsInfinityTools/docuseal-plus)
(Speedbits branding/disclaimers removed) and a net-new SAML SSO implementation:

- **User management** — Admin / Editor / Viewer roles with granular abilities and
  last-admin protection.
- **Company logo** — upload a logo (Account model), stamped on signatures and the
  audit trail.
- **Email reminders** — Sidekiq job that sends reminder emails for pending
  signatures, configurable per account.
- **UI tidy-ups** — hide the cloud-only upsell / plans / console / SMS menus
  (toggle in `lib/docuseal_sso.rb`).
- **SAML SSO** *(net-new in this overlay)* — `omniauth-saml` wired to Devise,
  with a real settings form (replacing the upstream "unlock with Pro"
  placeholder) that stores per-account IdP config in the `saml_configs`
  EncryptedConfig. Supports optional just-in-time user provisioning.

## How the build works

CI (`.github/workflows/docuseal-sso-build.yml`) applies the overlay to the
checkout and then builds with **upstream's own Dockerfile** — there is no
forked Dockerfile to drift when upstream changes base images, dependencies or
download sources:

| Step | Script | Mechanism | Used for |
|---|---|---|---|
| 0 | `sso/script/heal-patches.sh` | `git apply --3way` + regenerate | **Self-heal** patches that drifted after a fork sync (refresh is pushed back automatically) |
| 1 | `sso/script/apply-overlay.sh` | `rsync --ignore-existing` + appends | **New** files (never overwrites upstream); `sso/appends/*.append` are appended to churn-heavy upstream files (e.g. `Gemfile`) — position-independent, so they can never reject |
| 2 | `sso/script/apply-patches.sh` | `patch -p1` (unified diffs) | **Modifications** to existing upstream files |

The workflow also auto-disables any workflow that is not on its keep list, so
workflows upstream adds in the future can never leave a failing check on the
fork.

## Layout

```
sso/
├── README.md
├── overlay/                      # NEW files (rsync --ignore-existing)
│   ├── lib/docuseal_sso.rb                # feature flags
│   ├── lib/docuseal_pro/*.rb              # logo concern + stamp/audit overrides
│   ├── lib/saml_configs.rb                # builds omniauth-saml options from saml_configs
│   ├── config/initializers/docuseal_pro.rb   # loads logo overrides + schedules reminders
│   ├── config/initializers/omniauth_saml.rb  # registers the SAML provider (dynamic per-account)
│   ├── app/controllers/account_logo_controller.rb
│   ├── app/controllers/users/omniauth_callbacks_controller.rb
│   ├── app/jobs/{process_submitter_reminders,send_submitter_reminder_email}_job.rb
│   └── app/views/sso_settings/_form.html.erb
├── patches/                      # unified diffs to existing upstream files
├── appends/                      # blocks appended to upstream files (Gemfile)
├── script/{apply-overlay,apply-patches,heal-patches,build-local}.sh
└── deploy/{docker-compose.yml,.env.example}
```

## SAML SSO setup

1. Sign in as an admin → **Settings → SSO**.
2. Enter your IdP SSO URL and X.509 certificate (optionally entity IDs / attribute
   names). Configure your IdP with the ACS URL and metadata URL shown on that page
   (they live at `/auth/saml/callback` and `/auth/saml/metadata`).
3. Optionally enable just-in-time provisioning and pick a default role.
4. A **Sign in with SSO** button then appears on the login page.

> **Testing caveat:** the SAML SSO code is net-new and was authored without a
> running instance. Validate the IdP round-trip (login, callback, optional
> provisioning) on a live deployment before relying on it.

## Syncing upstream

```bash
git remote add upstream https://github.com/docusealco/docuseal.git   # once
git fetch upstream
git merge upstream/master        # or use GitHub's "Sync fork" button
git push                         # triggers .github/workflows/docuseal-sso-build.yml
```

Patch drift after a sync is normally **self-healed by CI** (`heal-patches.sh`
re-anchors the diff and pushes the refresh back). Manual work is only needed if
the build fails with a real conflict — upstream rewrote the exact lines a patch
changes. Then re-apply the change by hand and regenerate:

```bash
git diff -- <file> > sso/patches/<NNNN-name>.patch   # from a tree with the change applied
```

## Local build & run

```bash
sso/script/build-local.sh                      # stages a clean tree, applies overlay, builds
cp sso/deploy/.env.example sso/deploy/.env     # set SECRET_KEY_BASE, HOST
docker compose --env-file sso/deploy/.env -f sso/deploy/docker-compose.yml up -d
```
