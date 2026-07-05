# frozen_string_literal: true

# Per-account SMS provider settings, stored in the `sms_configs`
# EncryptedConfig (the key upstream's SmsSettingsController already loads for
# its Pro placeholder page). Modeled on SamlConfigs.
#
# value hash keys:
#   provider           - currently always 'ringcentral'
#   client_id          - RingCentral app client id
#   client_secret      - RingCentral app client secret
#   jwt_token          - RingCentral JWT credential (server-to-server auth)
#   server_url         - optional override (defaults to production RingCentral)
#   from_number        - the E.164 number SMS are sent from
#   available_numbers  - SMS-capable numbers fetched from the account
#   message_template   - optional custom SMS text ({{submitter.link}} etc.)
#   verified_at        - last successful credential verification
module SmsConfigs
  CONFIG_KEY = 'sms_configs'

  DEFAULT_MESSAGE = 'You are invited to sign "{{template.name}}" by {{account.name}}: {{submitter.link}}'

  module_function

  def find_or_initialize_for_account(account)
    EncryptedConfig.find_or_initialize_by(account:, key: CONFIG_KEY)
  end

  def value_for(account)
    EncryptedConfig.find_by(account:, key: CONFIG_KEY)&.value.presence || {}
  end

  def configured?(account)
    value = value_for(account)

    value['provider'] == 'ringcentral' &&
      value['client_id'].present? && value['client_secret'].present? &&
      value['jwt_token'].present? && value['from_number'].present?
  end

  def api_for(account)
    value = value_for(account)

    RingcentralApi.new(client_id: value['client_id'],
                       client_secret: value['client_secret'],
                       jwt_token: value['jwt_token'],
                       server_url: value['server_url'])
  end

  def message_template_for(account)
    value_for(account)['message_template'].presence || DEFAULT_MESSAGE
  end
end
