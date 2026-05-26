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
      # Literal NameID format (not SamlConfigs::DEFAULT_NAME_ID_FORMAT): this
      # runs at boot, before the lib/ autoloader can resolve SamlConfigs, so
      # referencing the constant here raises NameError and Puma fails to load.
      # The real per-account value is injected at request time by the setup
      # lambda below (where autoloading works). Keep this in sync with
      # SamlConfigs::DEFAULT_NAME_ID_FORMAT.
      name_identifier_format: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
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
