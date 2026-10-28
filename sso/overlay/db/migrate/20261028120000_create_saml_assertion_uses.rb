# frozen_string_literal: true

# SSO overlay: SAML assertion IDs already used to sign in, kept until the
# assertion expires so a captured SAMLResponse cannot be posted again.
class CreateSamlAssertionUses < ActiveRecord::Migration[8.1]
  def change
    create_table :saml_assertion_uses do |t|
      t.string :assertion_id, null: false
      t.datetime :expires_at, null: false

      t.datetime :created_at, null: false
    end

    add_index :saml_assertion_uses, :assertion_id, unique: true
    add_index :saml_assertion_uses, :expires_at
  end
end
