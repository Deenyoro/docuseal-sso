# frozen_string_literal: true

# Routes for the RingCentral SMS connector (Settings -> SMS) and the
# "Send SMS" button. Appended here instead of patching config/routes.rb so
# upstream route churn can never conflict with the overlay.
Rails.application.routes.append do
  unless Docuseal.multitenant?
    scope '/settings' do
      post 'sms', to: 'sms_configs#create', as: :settings_sms_configs
      delete 'sms', to: 'sms_configs#destroy'
    end
  end

  resources :submitters, only: %i[] do
    resources :send_sms, only: %i[create], controller: 'submitters_send_sms'
  end
end
