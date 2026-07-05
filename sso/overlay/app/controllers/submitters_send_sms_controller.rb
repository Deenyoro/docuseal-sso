# frozen_string_literal: true

# "Send SMS" / "Re-send SMS" button on the submission page — the SMS sibling
# of upstream's SubmittersSendEmailController.
class SubmittersSendSmsController < ApplicationController
  load_and_authorize_resource :submitter

  def create
    authorize!(:update, @submitter)

    if @submitter.phone.blank? || !SmsConfigs.configured?(current_account)
      return redirect_back(fallback_location: submission_path(@submitter.submission),
                           alert: I18n.t('sso_sms.not_configured'))
    end

    SendSubmitterInvitationSmsJob.perform_async('submitter_id' => @submitter.id)

    @submitter.sent_at ||= Time.current
    @submitter.save!

    redirect_back(fallback_location: submission_path(@submitter.submission),
                  notice: I18n.t('sso_sms.sms_has_been_sent'))
  end
end
