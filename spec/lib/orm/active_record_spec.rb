# frozen_string_literal: true

require "rails_helper"

# Regression coverage for #306.
#
# doorkeeper-openid_connect v1.10.0 (#241) wired the `openid_request`
# association onto the access grant model from inside an
# `ActiveSupport.on_load(:active_record)` block. That hook fires while
# `ActiveRecord::Base` is first loaded — e.g. mid-evaluation of
# `class ApplicationRecord < ActiveRecord::Base` — so constantizing a
# namespaced custom grant model (`Auth::OAuthAccessGrant < ApplicationRecord`)
# from the hook raised `NameError: uninitialized constant Auth::ApplicationRecord`.
#
# The fix wires the association from Doorkeeper's AccessGrant mixin
# `included` callback instead, at the host model's own load time, without
# constantizing anything. These specs pin that behavior.
describe "Doorkeeper::OpenidConnect ActiveRecord ORM integration" do
  describe "the openid_request association" do
    it "is wired onto the default access grant model" do
      association = Doorkeeper.config.access_grant_model.reflect_on_association(:openid_request)
      expect(association).not_to be_nil
    end

    it "is wired onto a namespaced custom model that includes Doorkeeper's mixin" do
      # Mirrors the #306 reporter's setup: a namespaced model subclassing
      # the host app's ApplicationRecord and including the doorkeeper mixin.
      # Because the association is added from the mixin's `included` callback
      # (not a deferred load hook), the model is wired at its own load time
      # without anything constantizing the configured grant class.
      stub_const("Auth306", Module.new)
      custom_model = Class.new(ApplicationRecord) do
        self.table_name = "oauth_access_grants"
        include Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant
      end
      Auth306.const_set(:OAuthAccessGrant, custom_model)

      association = custom_model.reflect_on_association(:openid_request)
      expect(association).not_to be_nil
      expect(association.options[:class_name])
        .to eq(Doorkeeper::OpenidConnect.configuration.open_id_request_class)
    end
  end
end
