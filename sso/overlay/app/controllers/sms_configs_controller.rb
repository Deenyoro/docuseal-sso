# frozen_string_literal: true

# Saves and verifies the RingCentral SMS connector settings shown on
# Settings -> SMS (the form replaces upstream's Pro placeholder). Mirrors the
# authorization of upstream's SmsSettingsController.
class SmsConfigsController < ApplicationController
  before_action :load_encrypted_config
  authorize_resource :encrypted_config, parent: false

  def create
    value = @encrypted_config.value.presence || {}

    value['provider'] = 'ringcentral'
    value['client_id'] = config_params[:client_id].presence || value['client_id']
    # Secret fields keep their stored value when left blank on re-save.
    value['client_secret'] = config_params[:client_secret].presence || value['client_secret']
    value['jwt_token'] = config_params[:jwt_token].presence || value['jwt_token']
    value['server_url'] = config_params[:server_url].to_s.strip.presence
    value['message_template'] = config_params[:message_template].to_s.strip.presence
    value['from_number'] = config_params[:from_number].presence || value['from_number']

    if value['client_id'].blank? || value['client_secret'].blank? || value['jwt_token'].blank?
      return redirect_to settings_sms_index_path, alert: I18n.t('sso_sms.missing_credentials')
    end

    api = RingcentralApi.new(client_id: value['client_id'],
                             client_secret: value['client_secret'],
                             jwt_token: value['jwt_token'],
                             server_url: value['server_url'])

    numbers = api.sms_numbers

    value['available_numbers'] = numbers
    value['verified_at'] = Time.current
    value['from_number'] = numbers.first['phone_number'] if value['from_number'].blank? && numbers.size == 1

    @encrypted_config.value = value
    @encrypted_config.save!

    if value['from_number'].blank?
      redirect_to settings_sms_index_path, notice: I18n.t('sso_sms.verified_pick_number')
    else
      redirect_to settings_sms_index_path, notice: I18n.t('sso_sms.connector_saved')
    end
  rescue RingcentralApi::ApiError, Faraday::Error => e
    # Keep what the admin typed so they can correct a single field, but mark
    # the connector unverified.
    value['verified_at'] = nil
    @encrypted_config.value = value
    @encrypted_config.save!

    redirect_to settings_sms_index_path, alert: "#{I18n.t('sso_sms.verification_failed')}: #{e.message}"
  end

  def destroy
    @encrypted_config.destroy! if @encrypted_config.persisted?

    redirect_to settings_sms_index_path, notice: I18n.t('sso_sms.connector_removed')
  end

  private

  def load_encrypted_config
    @encrypted_config =
      EncryptedConfig.find_or_initialize_by(account: current_account, key: SmsConfigs::CONFIG_KEY)
  end

  def config_params
    params.require(:sms_configs).permit(:client_id, :client_secret, :jwt_token, :server_url,
                                        :from_number, :message_template)
  end
end
