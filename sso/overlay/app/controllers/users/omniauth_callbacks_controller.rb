# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # SAML assertion is signed by the IdP; OmniAuth verifies it. The callback
    # itself is a POST from the IdP, so skip the app CSRF check here.
    skip_before_action :verify_authenticity_token, raise: false

    def saml
      auth = request.env['omniauth.auth']
      account = SamlConfigs.account_for

      return reject(I18n.t('single_sign_on_is_not_configured')) if account.blank?

      email = extract_email(auth)
      return reject(I18n.t('the_sso_response_did_not_include_an_email')) if email.blank?

      user = account.users.where(archived_at: nil).find_by('lower(email) = ?', email)
      user ||= provision_user(account, email, auth)

      if user&.persisted? && user.archived_at.nil?
        sign_in_and_redirect(user, event: :authentication)
      else
        reject(I18n.t('your_account_could_not_be_found_please_contact_your_administrator'))
      end
    end

    def failure
      reject(failure_message.presence || I18n.t('single_sign_on_failed'))
    end

    private

    def reject(message)
      redirect_to new_user_session_path, alert: message
    end

    def extract_email(auth)
      (auth&.info&.email || auth&.uid).to_s.strip.downcase.presence
    end

    # Just-in-time provisioning, only when explicitly enabled in the SAML config.
    # New users default to a non-admin role to avoid privilege escalation via SSO.
    def provision_user(account, email, auth)
      config = SamlConfigs.config_record(account)&.value || {}
      return nil unless ActiveModel::Type::Boolean.new.cast(config['auto_provision'])

      role = config['default_role'].to_s.presence_in(User::SELECTABLE_ROLES) || User::EDITOR_ROLE

      user = account.users.create(
        email:,
        first_name: auth&.info&.first_name.presence || email.split('@').first,
        last_name: auth&.info&.last_name.presence || '',
        role:,
        password: SecureRandom.base58(24)
      )

      user.persisted? ? user : nil
    end

    def failure_message
      request.env['omniauth.error']&.message
    end
  end
end
