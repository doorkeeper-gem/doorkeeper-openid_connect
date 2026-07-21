# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect, "configuration" do
  subject { described_class.configuration }

  describe "#configure" do
    it "fails if not set to :active_record" do
      # stub ORM setup to avoid Doorkeeper exceptions
      allow(Doorkeeper).to receive(:setup_orm_adapter)
      allow(Doorkeeper).to receive(:setup_orm_models)
      allow(Doorkeeper).to receive(:setup_application_owner)

      Doorkeeper.configure do
        orm :mongoid
      end

      expect do
        described_class.configure {}
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end

    it "fails validation if id_token doesn't implement required methods" do
      stub_const("CustomIdToken", Class.new)

      expect do
        described_class.configure do
          id_token_class "CustomIdToken"
        end
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration,
                         "The configured id_token_class (CustomIdToken) is missing the following " \
                         "required methods: as_jws_token, issuer"
    end

    it "fails validation if user_info doesn't implement required methods" do
      # NOTE: Since ActiveSupport already puts `#as_json` on `Object`, this test really doesn't do
      # much. It's still good for semantic correctness, I guess?

      expect do
        described_class.configure do
          user_info_class "Object"
        end
      end.not_to raise_error
    end

    it "fails validation if user_info is missing as_json" do
      # ActiveSupport defines `#as_json` on Object, so the method has to be
      # undefined explicitly to model a class that does not fulfill the contract.
      stub_const("CustomUserInfo", Class.new { undef_method :as_json })

      expect do
        described_class.configure do
          user_info_class "CustomUserInfo"
        end
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration,
                         "The configured user_info_class (CustomUserInfo) is missing the following " \
                         "required methods: as_json"
    end
  end

  describe ".configuration" do
    it "raises MissingConfiguration when the gem has not been configured" do
      saved = described_class.instance_variable_get(:@config)
      described_class.instance_variable_set(:@config, nil)

      expect do
        described_class.configuration
      end.to raise_error Doorkeeper::OpenidConnect::Errors::MissingConfiguration,
                         /doorkeeper_openid_connect initializer/
    ensure
      described_class.instance_variable_set(:@config, saved)
    end
  end

  describe "jws_public_key" do
    it "warns that the setting is no longer needed" do
      expect do
        described_class.configure do
          jws_public_key "public_key"
        end
      end.to output(/DEPRECATION WARNING: `jws_public_key` is not needed anymore/).to_stderr
    end
  end

  describe "jws_private_key" do
    it "delegates to signing_key" do
      value = "private_key"
      described_class.configure do
        jws_private_key value
      end
      expect(subject.signing_key).to eq(value)
    end
  end

  describe "signing_key" do
    it "sets the value that is accessible via signing_key" do
      value = "private_key"
      described_class.configure do
        signing_key value
      end
      expect(subject.signing_key).to eq(value)
    end
  end

  describe "issuer" do
    it "sets the value that is accessible via issuer" do
      value = "issuer"
      described_class.configure do
        issuer value
      end
      expect(subject.issuer).to eq(value)
    end

    it "sets the block that is accessible via issuer" do
      block = proc {}
      described_class.configure do
        issuer(&block)
      end
      expect(subject.issuer).to eq(block)
    end
  end

  describe "resource_owner_from_access_token" do
    it "sets the block that is accessible via resource_owner_from_access_token" do
      block = proc {}
      described_class.configure do
        resource_owner_from_access_token(&block)
      end
      expect(subject.resource_owner_from_access_token).to eq(block)
    end

    it "fails if unset" do
      described_class.configure {}

      expect do
        subject.resource_owner_from_access_token.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe "auth_time_from_resource_owner" do
    it "sets the block that is accessible via auth_time_from_resource_owner" do
      block = proc {}
      described_class.configure do
        auth_time_from_resource_owner(&block)
      end
      expect(subject.auth_time_from_resource_owner).to eq(block)
    end

    it "fails if unset" do
      described_class.configure {}

      expect do
        subject.auth_time_from_resource_owner.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe "auth_time_from_session" do
    it "defaults to nil" do
      described_class.configure {}

      expect(subject.auth_time_from_session).to be_nil
    end

    it "sets the block that is accessible via auth_time_from_session" do
      block = proc {}
      described_class.configure do
        auth_time_from_session(&block)
      end
      expect(subject.auth_time_from_session).to eq(block)
    end
  end

  describe "auth_time_from_access_token" do
    it "defaults to nil" do
      described_class.configure {}

      expect(subject.auth_time_from_access_token).to be_nil
    end

    it "sets the block that is accessible via auth_time_from_access_token" do
      block = proc {}
      described_class.configure do
        auth_time_from_access_token(&block)
      end
      expect(subject.auth_time_from_access_token).to eq(block)
    end
  end

  describe "reauthenticate_resource_owner" do
    it "sets the block that is accessible via reauthenticate_resource_owner" do
      block = proc {}
      described_class.configure do
        reauthenticate_resource_owner(&block)
      end
      expect(subject.reauthenticate_resource_owner).to eq(block)
    end

    it "fails if unset" do
      described_class.configure {}

      expect do
        subject.reauthenticate_resource_owner.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe "select_account_for_resource_owner" do
    it "sets the block that is accessible via select_account_for_resource_owner" do
      block = proc {}
      described_class.configure do
        select_account_for_resource_owner(&block)
      end
      expect(subject.select_account_for_resource_owner).to eq(block)
    end

    it "fails if unset" do
      described_class.configure {}

      expect do
        subject.select_account_for_resource_owner.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe "subject" do
    it "sets the block that is accessible via subject" do
      block = proc {}
      described_class.configure do
        subject(&block)
      end
      expect(subject.subject).to eq(block)
    end

    it "fails if unset" do
      described_class.configure {}

      expect do
        subject.subject.call
      end.to raise_error Doorkeeper::OpenidConnect::Errors::InvalidConfiguration
    end
  end

  describe "expiration" do
    it "sets the value that is accessible via expiration" do
      value = "expiration"
      described_class.configure do
        expiration value
      end
      expect(subject.expiration).to eq(value)
    end
  end

  describe "id_token_class" do
    before do
      stub_const("CustomIdToken", Class.new(Doorkeeper::OpenidConnect::IdToken))
    end

    it "defaults to Doorkeeper::OpenidConnect::IdToken" do
      described_class.configure {}

      expect(subject.id_token_class).to eq("Doorkeeper::OpenidConnect::IdToken")
    end

    it "sets the value that is accessible via id_token_class" do
      described_class.configure do
        id_token_class "CustomIdToken"
      end

      expect(subject.id_token_class).to eq("CustomIdToken")
    end
  end

  describe "#id_token_model" do
    it "constantizes the default id_token_class" do
      described_class.configure {}

      expect(subject.id_token_model).to eq(Doorkeeper::OpenidConnect::IdToken)
    end

    it "constantizes a custom id_token_class" do
      stub_const("CustomIdToken", Class.new(Doorkeeper::OpenidConnect::IdToken))

      described_class.configure do
        id_token_class "CustomIdToken"
      end

      expect(subject.id_token_model).to eq(CustomIdToken)
    end
  end

  describe "user_info_class" do
    before do
      stub_const("CustomUserInfo", Class.new(Doorkeeper::OpenidConnect::UserInfo))
    end

    it "defaults to Doorkeeper::OpenidConnect::UserInfo" do
      described_class.configure {}

      expect(subject.user_info_class).to eq("Doorkeeper::OpenidConnect::UserInfo")
    end

    it "sets the value that is accessible via user_info_class" do
      described_class.configure do
        user_info_class "CustomUserInfo"
      end

      expect(subject.user_info_class).to eq("CustomUserInfo")
    end
  end

  describe "#user_info_model" do
    it "constantizes the default user_info_class" do
      described_class.configure {}

      expect(subject.user_info_model).to eq(Doorkeeper::OpenidConnect::UserInfo)
    end

    it "constantizes a custom user_info_class" do
      stub_const("CustomUserInfo", Class.new(Doorkeeper::OpenidConnect::UserInfo))

      described_class.configure do
        user_info_class "CustomUserInfo"
      end

      expect(subject.user_info_model).to eq(CustomUserInfo)
    end
  end

  describe "claims" do
    it "sets the claims configuration that is accessible via claims" do
      described_class.configure do
        claims do
        end
      end
      expect(subject.claims).not_to be_nil
    end
  end

  describe "protocol" do
    it "defaults to https in production" do
      expect(::Rails.env).to receive(:production?).and_return(true)

      expect(subject.protocol.call).to eq(:https)
    end

    it "defaults to http in other environments" do
      expect(::Rails.env).to receive(:production?).and_return(false)

      expect(subject.protocol.call).to eq(:http)
    end

    it "can be set to other protocols" do
      described_class.configure do
        protocol { :ftp }
      end

      expect(subject.protocol.call).to eq(:ftp)
    end
  end

  describe "end_session_endpoint" do
    it "defaults to nil" do
      expect(subject.end_session_endpoint.call).to be_nil
    end

    it "can be set to a custom url" do
      described_class.configure do
        end_session_endpoint { "http://test.host/logout" }
      end

      expect(subject.end_session_endpoint.call).to eq("http://test.host/logout")
    end
  end

  describe "apply_prompt_to_non_oidc_requests" do
    it "defaults to false" do
      described_class.configure {}

      expect(subject.apply_prompt_to_non_oidc_requests).to be(false)
    end

    it "can be enabled" do
      described_class.configure do
        apply_prompt_to_non_oidc_requests true
      end

      expect(subject.apply_prompt_to_non_oidc_requests).to be(true)
    end
  end

  describe "discovery_url_options" do
    it "defaults to empty hash" do
      expect(subject.discovery_url_options.call).to be_a(Hash)
      expect(subject.discovery_url_options.call).to be_empty
    end

    it "can be set to other hosts" do
      described_class.configure do
        discovery_url_options do |_request|
          {
            authorization: { host: "alternate-authorization-host" },
            token: { host: "alternate-token-host" },
            revocation: { host: "alternate-revocation-host" },
            introspection: { host: "alternate-introspection-host" },
            userinfo: { host: "alternate-userinfo-host" },
            jwks: { host: "alternate-jwks-host" },
          }
        end
      end

      expect(subject.discovery_url_options.call[:authorization]).to eq(host: "alternate-authorization-host")
    end
  end
end
