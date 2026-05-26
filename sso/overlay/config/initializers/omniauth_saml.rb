# frozen_string_literal: true

# Registers the SAML OmniAuth provider for Devise.
#
# Per-account IdP settings are not known at boot, so static placeholders are
# used here and the real options are injected per-request by the `setup` lambda,
# which reads them from the `saml_configs` EncryptedConfig via SamlConfigs.
#
# Loads after config/initializers/devise.rb (alphabetical order), so the Devise
# OmniAuth machinery is already configured.
if defined?(OmniAuth::Strategies::SAML)
  Devise.setup do |config|
    config.omniauth(
      :saml,
      idp_sso_service_url: 'https://example.invalid/sso',
      idp_cert: '',
      sp_entity_id: 'docuseal',
      name_identifier_format: SamlConfigs::DEFAULT_NAME_ID_FORMAT,
      setup: lambda do |env|
        strategy = env['omniauth.strategy']
        options = SamlConfigs.omniauth_options
        strategy.options.merge!(options) if options.present?
      rescue StandardError => e
        Rails.logger.error("SAML setup failed: #{e.message}")
      end
    )
  end
else
  Rails.logger.warn('omniauth-saml not loaded; SAML SSO disabled')
end
