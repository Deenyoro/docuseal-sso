# frozen_string_literal: true

# A SAML assertion ID that was accepted for sign-in. ruby-saml checks the
# signature and the time window of a response but keeps no record of what it
# has seen, so without this a captured SAMLResponse could be posted again until
# it expires. Rows are kept until the assertion's own expiry and then pruned.
class SamlAssertionUse < ApplicationRecord
  # Minimum time an ID is remembered, for IdPs that send a short or no
  # Conditions NotOnOrAfter (the subject confirmation window still applies).
  MIN_RETENTION = 1.hour

  # Records the assertion ID. Returns false when it was already used.
  def self.claim(assertion_id, not_on_or_after)
    return false if assertion_id.blank?

    now = Time.current

    where(expires_at: ...now).delete_all

    create!(assertion_id:, expires_at: [not_on_or_after, now + MIN_RETENTION].compact.max, created_at: now)

    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
