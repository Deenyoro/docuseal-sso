# frozen_string_literal: true

# Enforces the `force_sso_auth` account setting (DocuSeal ships the setting but
# not the enforcement in open-core). When the flag is on AND SAML is configured,
# email/password login and password reset are rejected so SSO is the only way
# in. DocusealSso.force_sso_active? fails safe (false) if SAML isn't configured
# or the check errors, so you can never lock yourself out.
#
# Prepended in `to_prepare` (the Rails-recommended hook for patching autoloaded
# classes) so the controllers resolve via the autoloader, not at boot.

module DocusealSso
  module ForcePasswordLoginBlock
    def create
      if DocusealSso.force_sso_active?
        redirect_to(new_user_session_path,
                    alert: I18n.t('force_sso_disable_login_with_email_and_password'))
        return
      end
      super
    end
  end

  # Block password-reset request + completion so reset-email can't be used as a
  # bypass (Devise's passwords#update auto-signs-in, skipping sessions#create).
  module ForcePasswordResetBlock
    def create
      return reject_sso if DocusealSso.force_sso_active?

      super
    end

    def update
      return reject_sso if DocusealSso.force_sso_active?

      super
    end

    private

    def reject_sso
      redirect_to(new_user_session_path,
                  alert: I18n.t('force_sso_disable_login_with_email_and_password'))
    end
  end
end

Rails.application.config.to_prepare do
  if defined?(SessionsController) &&
     !SessionsController.ancestors.include?(DocusealSso::ForcePasswordLoginBlock)
    SessionsController.prepend(DocusealSso::ForcePasswordLoginBlock)
  end

  if defined?(PasswordsController) &&
     !PasswordsController.ancestors.include?(DocusealSso::ForcePasswordResetBlock)
    PasswordsController.prepend(DocusealSso::ForcePasswordResetBlock)
  end
end
