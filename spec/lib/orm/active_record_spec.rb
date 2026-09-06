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

    it "defers wiring when the mixin is included via an intermediate concern" do
      # `AccessGrantExtension#included` first fires with the intermediate
      # module itself (not a class); the concern machinery re-fires it with
      # the model class once that includes the concern, and only then must
      # the association be wired.
      intermediate = Module.new do
        extend ActiveSupport::Concern
        include Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant
      end

      expect(intermediate.ancestors).not_to include(Doorkeeper::OpenidConnect::AccessGrant)

      custom_model = Class.new(ApplicationRecord) do
        self.table_name = "oauth_access_grants"
        include intermediate
      end

      expect(custom_model.ancestors).to include(Doorkeeper::OpenidConnect::AccessGrant)
      expect(custom_model.reflect_on_association(:openid_request)).not_to be_nil
    end
  end

  # Regression coverage for the boot failure introduced in v1.10.3 (#308).
  #
  # Since #308 the association is wired from the grant mixin's `included`
  # callback, so it is evaluated whenever the model loads — which the host
  # application can easily arrange to happen before
  # `Doorkeeper::OpenidConnect.configure` runs: Doorkeeper's own
  # `initialize_models!` reaches for the grant model from `Doorkeeper.configure`
  # (immediately, on Doorkeeper 5.5.x with `ActiveRecord::Base` already loaded),
  # and any initializer sorting between `doorkeeper.rb` and
  # `doorkeeper_openid_connect.rb` can name the model itself. Reading
  # `open_id_request_class` at that point raised `MissingConfiguration`, whose
  # message ("Do you have doorkeeper_openid_connect initializer?") points at an
  # initializer that does exist and simply has not run yet. #174 is the same
  # ordering hazard one layer down: an unrelated gem (Sorcery) loaded
  # `ActiveRecord::Base` before the doorkeeper initializers, and Doorkeeper's
  # own model wiring reported a missing Doorkeeper initializer.
  describe "an access grant model that loads before the OpenID Connect configuration" do
    around do |example|
      previous_config = Doorkeeper::OpenidConnect.instance_variable_get(:@config)
      Doorkeeper::OpenidConnect.instance_variable_set(:@config, nil)
      example.run
    ensure
      Doorkeeper::OpenidConnect.instance_variable_set(:@config, previous_config)
    end

    def load_grant_model
      Class.new(ApplicationRecord) do
        self.table_name = "oauth_access_grants"
        include Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant
      end
    end

    it "does not raise MissingConfiguration" do
      expect { load_grant_model }.not_to raise_error
    end

    it "wires the association once the configuration arrives" do
      custom_model = load_grant_model

      expect(custom_model.reflect_on_association(:openid_request)).to be_nil

      Doorkeeper::OpenidConnect.configure do
        issuer "dummy"
        open_id_request_class "CustomOpenidRequest308"
      end

      association = custom_model.reflect_on_association(:openid_request)
      expect(association).not_to be_nil
      expect(association.options[:class_name]).to eq("CustomOpenidRequest308")
    end
  end
end
