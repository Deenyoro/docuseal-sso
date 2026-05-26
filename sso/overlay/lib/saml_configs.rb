# frozen_string_literal: true

# Builds OmniAuth SAML options from the per-account SAML settings stored in the
# `saml_configs` EncryptedConfig, and resolves which account a SAML request is
# for.
#
# DocuSeal on-premises is effectively single-tenant (one account), so when no
# account hint is present we fall back to the single account that has SAML
# configured. The stored config is a plain hash with these keys:
#
#   idp_sso_service_url   - IdP SSO (login) URL                 [required]
#   idp_slo_service_url   - IdP SLO (logout) URL                [optional]
#   idp_cert              - IdP signing certificate (PEM/x509)  [required]
#   idp_entity_id         - IdP entity id / issuer              [optional]
#   sp_entity_id          - SP entity id (this app)             [optional]
#   name_identifier_format
#   email_attribute       - assertion attribute holding email   [default: email]
#   first_name_attribute
#   last_name_attribute
#   auto_provision        - create users on first sign-in       [default: false]
#   default_role          - role for provisioned users          [default: editor]
module SamlConfigs
  CONFIG_KEY = 'saml_configs'
  DEFAULT_NAME_ID_FORMAT = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
  FALLBACK_CALLBACK_PATH = '/auth/saml/callback'

  module_function

  # The EncryptedConfig row that holds SAML settings (single-tenant fallback).
  def config_record(account = nil)
    scope = EncryptedConfig.where(key: CONFIG_KEY)
    scope = scope.where(account:) if account
    scope.where.not(value: nil).first
  end

  def configured?(account = nil)
    record = config_record(account)
    record.present? && record.value.present? && record.value['idp_sso_service_url'].present?
  end

  def account_for(account = nil)
    config_record(account)&.account
  end

  # OmniAuth SAML options hash built from the stored config.
  def omniauth_options(account = nil)
    record = config_record(account)
    return {} if record.blank? || record.value.blank?

    value = record.value

    {
      idp_sso_service_url: value['idp_sso_service_url'],
      idp_slo_service_url: value['idp_slo_service_url'].presence,
      idp_cert: value['idp_cert'].presence,
      idp_entity_id: value['idp_entity_id'].presence,
      issuer: value['sp_entity_id'].presence || default_sp_entity_id,
      assertion_consumer_service_url: callback_url,
      name_identifier_format: value['name_identifier_format'].presence || DEFAULT_NAME_ID_FORMAT,
      attribute_statements: {
        email: [value['email_attribute'].presence || 'email',
                'urn:oid:0.9.2342.19200300.100.1.3', 'mail'].compact,
        first_name: [value['first_name_attribute'].presence || 'first_name',
                     'urn:oid:2.5.4.42', 'givenName'].compact,
        last_name: [value['last_name_attribute'].presence || 'last_name',
                    'urn:oid:2.5.4.4', 'sn'].compact
      }
    }.compact
  end

  # --- URL helpers -----------------------------------------------------------
  # Derived from the real Devise route (which lives at /auth/saml/* because
  # devise_for uses path: '/'), so they stay correct regardless of routing.

  def callback_path
    Rails.application.routes.url_helpers.user_saml_omniauth_callback_path
  rescue StandardError
    FALLBACK_CALLBACK_PATH
  end

  def callback_url
    "#{base_url}#{callback_path}"
  end

  def metadata_url
    "#{base_url}#{callback_path.sub(%r{/callback\z}, '/metadata')}"
  end

  def default_sp_entity_id
    metadata_url
  end

  def base_url
    opts = url_options
    url = "#{opts[:protocol] || 'https'}://#{opts[:host]}"
    url += ":#{opts[:port]}" if opts[:port].present? && ![80, 443].include?(opts[:port].to_i)
    url
  end

  def url_options
    Docuseal.default_url_options
  rescue StandardError
    Docuseal::DEFAULT_URL_OPTIONS
  end
end
