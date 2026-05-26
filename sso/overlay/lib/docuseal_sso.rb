# frozen_string_literal: true

# DocuSeal SSO overlay configuration.
#
# Central feature-flag module for the SSO overlay. The functional features
# (user roles, company logo, email reminders) and the UI tidy-ups (hiding the
# upsell/plans/console/SMS menus that point at the paid cloud) are toggled
# here. Flip any flag to false to fall back to upstream behaviour.
module DocusealSso
  class << self
    def config
      @config ||= {
        # Feature flags
        user_roles_enabled: true,
        company_logo_enabled: true,
        email_reminders_enabled: true,

        # UI tidy-ups (hide links that only make sense on the paid cloud)
        hide_upgrade_button: true,
        hide_plans_menu: true,
        hide_sms_menu: true,
        hide_console_menu: true,
        hide_sso_menu: false,
        hide_trusted_signature_promo: true
      }
    end

    def enabled?(feature)
      config[feature] == true
    end

    def setting(key)
      config[key]
    end

    def hide_upgrade_button?
      enabled?(:hide_upgrade_button)
    end

    def hide_plans_menu?
      enabled?(:hide_plans_menu)
    end

    def hide_sms_menu?
      enabled?(:hide_sms_menu)
    end

    def hide_console_menu?
      enabled?(:hide_console_menu)
    end

    def hide_sso_menu?
      enabled?(:hide_sso_menu)
    end

    def hide_trusted_signature_promo?
      enabled?(:hide_trusted_signature_promo)
    end
  end
end
