# frozen_string_literal: true

# Enqueues SMS signature-request invitations alongside the email dispatch in
# Submitters.send_signature_requests (single-line hook patched into
# lib/submitters.rb). Sends only when the submitter has a phone, the
# "Send via SMS" preference was explicitly enabled, and RingCentral is
# configured for the account.
module SsoSmsInvitations
  module_function

  def maybe_enqueue(submitter, index: 0, delay_seconds: nil)
    return if submitter.phone.blank?
    return if submitter.declined_at?
    return unless submitter.preferences['send_sms'] == true
    return unless SmsConfigs.configured?(submitter.account)

    if delay_seconds
      SendSubmitterInvitationSmsJob.perform_in((delay_seconds + index).seconds, 'submitter_id' => submitter.id)
    else
      SendSubmitterInvitationSmsJob.perform_async('submitter_id' => submitter.id)
    end
  end
end
