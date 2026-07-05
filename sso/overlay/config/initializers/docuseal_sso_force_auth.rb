# frozen_string_literal: true

# Enforces the `force_sso_auth` account setting (DocuSeal ships the setting but
# not the enforcement in open-core). When the flag is on AND SAML is configured,
# email/password login and password reset are rejected so SSO is the only way
# in. DocusealSso.force_sso_active? fails safe (false) if SAML isn't configured
# or the check errors, so you can never lock yourself out.
#
# The override modules are intentionally NOT nested under `DocusealSso`:
# reopening that module here would pre-define the constant and stop Zeitwerk
# from autoloading lib/docuseal_sso.rb (where force_sso_active? lives).
# Prepended in `to_prepare` so the controllers resolve via the autoloader.

module ForceSsoPasswordLoginBlock
  def create
    if DocusealSso.force_sso_active?
      redirect_to(new_user_session_path,
                  alert: I18n.t('force_sso_disable_login_with_email_and_password'))
      return
    end
    super
  end
end

# Block password-reset request + completion too: Devise's passwords#update
# auto-signs-in, which would otherwise bypass the sessions#create block.
module ForceSsoPasswordResetBlock
  def create
    return force_sso_reject if DocusealSso.force_sso_active?

    super
  end

  def update
    return force_sso_reject if DocusealSso.force_sso_active?

    super
  end

  private

  def force_sso_reject
    redirect_to(new_user_session_path,
                alert: I18n.t('force_sso_disable_login_with_email_and_password'))
  end
end

Rails.application.config.to_prepare do
  if defined?(SessionsController) && !(SessionsController <= ForceSsoPasswordLoginBlock)
    SessionsController.prepend(ForceSsoPasswordLoginBlock)
  end

  if defined?(PasswordsController) && !(PasswordsController <= ForceSsoPasswordResetBlock)
    PasswordsController.prepend(ForceSsoPasswordResetBlock)
  end
end
