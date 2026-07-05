# frozen_string_literal: true

# Minimal RingCentral REST client for sending SMS signature-request
# invitations. Ported from the zammad-kc Kc::RingcentralApi connector, reduced
# to what DocuSeal needs (JWT server-to-server auth, send SMS, list numbers).
#
# Auth is RingCentral's JWT credentials flow (grant_type jwt-bearer): the admin
# creates a server-to-server app in the RingCentral developer console and
# issues a JWT credential for it — no browser OAuth round-trip, no rotating
# refresh tokens to persist. Access tokens last ~1h and are cached for 45min.
class RingcentralApi
  DEFAULT_SERVER_URL = 'https://platform.ringcentral.com'
  JWT_GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
  TOKEN_CACHE_TTL = 45.minutes

  class ApiError < StandardError; end

  attr_reader :client_id, :client_secret, :jwt_token, :server_url

  def initialize(client_id:, client_secret:, jwt_token:, server_url: nil)
    @client_id = client_id
    @client_secret = client_secret
    @jwt_token = jwt_token
    @server_url = server_url.presence || DEFAULT_SERVER_URL
  end

  # POST /restapi/v1.0/account/~/extension/~/sms
  def send_sms(from:, to:, text:)
    api_post('/restapi/v1.0/account/~/extension/~/sms',
             from: { phoneNumber: from },
             to: Array(to).map { |number| { phoneNumber: number } },
             text: text)
  end

  # GET /restapi/v1.0/account/~/extension/~/phone-number
  def phone_numbers
    api_get('/restapi/v1.0/account/~/extension/~/phone-number', perPage: 500)['records'].to_a
  end

  # Numbers usable as the SMS "from" number.
  def sms_numbers
    phone_numbers.filter_map do |record|
      next unless record['features'].to_a.include?('SmsSender')

      { 'phone_number' => record['phoneNumber'],
        'usage_type' => record['usageType'],
        'label' => record['label'].presence }
    end
  end

  # Cheap credential check: acquiring a token proves client id/secret + JWT.
  def verify!
    access_token(force: true)

    true
  end

  def access_token(force: false)
    cache_key = "ringcentral_api_token:#{Digest::SHA256.hexdigest("#{client_id}:#{jwt_token}")}"

    Rails.cache.delete(cache_key) if force

    Rails.cache.fetch(cache_key, expires_in: TOKEN_CACHE_TTL) { request_access_token }
  end

  # Best-effort E.164 normalization (US default), same rules as the zammad-kc
  # connector: strip formatting, add +1 to bare 10-digit numbers.
  def self.normalize_phone(phone)
    digits = phone.to_s.gsub(/[^0-9+]/, '')

    return digits if digits.start_with?('+')
    return "+1#{digits}" if digits.length == 10
    return "+#{digits}" if digits.length == 11 && digits.start_with?('1')

    "+#{digits}"
  end

  private

  def request_access_token
    response = connection.post('/restapi/oauth/token') do |req|
      req.headers['Authorization'] = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form(grant_type: JWT_GRANT_TYPE, assertion: jwt_token)
    end

    body = parse_body(response)

    raise ApiError, error_message(response, body) unless response.success? && body['access_token'].present?

    body['access_token']
  end

  def api_get(path, params = {})
    handle_response(connection.get(path, params) { |req| req.headers['Authorization'] = bearer })
  end

  def api_post(path, payload)
    response = connection.post(path) do |req|
      req.headers['Authorization'] = bearer
      req.headers['Content-Type'] = 'application/json'
      req.body = payload.to_json
    end

    handle_response(response)
  end

  def handle_response(response)
    body = parse_body(response)

    raise ApiError, error_message(response, body) unless response.success?

    body
  end

  def parse_body(response)
    JSON.parse(response.body.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def error_message(response, body)
    detail = body['message'] || body['error_description'] ||
             body.dig('errors', 0, 'message') || body['error'] || response.body.to_s.first(200)

    "RingCentral API error (#{response.status}): #{detail}"
  end

  def bearer
    "Bearer #{access_token}"
  end

  def connection
    @connection ||= Faraday.new(url: server_url) do |faraday|
      faraday.options.open_timeout = 10
      faraday.options.timeout = 30
      faraday.adapter Faraday.default_adapter
    end
  end
end
