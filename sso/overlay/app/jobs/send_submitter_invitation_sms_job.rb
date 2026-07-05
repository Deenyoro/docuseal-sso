# frozen_string_literal: true

# The SMS sibling of SendSubmitterInvitationEmailJob. Upstream already
# references this class from SubmittersController#maybe_resend_email_sms (the
# Pro edition defines it in cloud code); this overlay implementation sends the
# signing link via the account's RingCentral connector.
class SendSubmitterInvitationSmsJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(params = {})
    submitter = Submitter.find(params['submitter_id'])

    return if submitter.phone.blank?
    return if submitter.completed_at?
    return if submitter.declined_at?
    return if submitter.submission.archived_at?
    return if submitter.submission.expired?
    return if submitter.template&.archived_at?

    account = submitter.account

    return unless SmsConfigs.configured?(account)

    text = ReplaceEmailVariables.call(SmsConfigs.message_template_for(account),
                                      submitter:,
                                      tracking_event_type: 'click_sms')

    SmsConfigs.api_for(account).send_sms(from: SmsConfigs.value_for(account)['from_number'],
                                         to: RingcentralApi.normalize_phone(submitter.phone),
                                         text:)

    SubmissionEvent.create!(submitter:, event_type: 'send_sms')

    submitter.sent_at ||= Time.current
    submitter.save!
  end
end
