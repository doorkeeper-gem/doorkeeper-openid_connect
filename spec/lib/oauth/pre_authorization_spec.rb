# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::OAuth::PreAuthorization do
  subject { Doorkeeper::OAuth::PreAuthorization.new server, attrs }

  let(:server) { Doorkeeper.configuration }
  let(:attrs) {}

  describe "#initialize" do
    context "with nonce parameter" do
      let(:attrs) { { nonce: "123456" } }

      it "stores the nonce attribute" do
        expect(subject.nonce).to eq "123456"
      end
    end
  end

  # `#as_json` is what Doorkeeper serializes for the `api_only` consent step,
  # so it is the only channel a nonce has when no view is rendered.
  describe "#as_json" do
    let(:application) { create(:application) }
    let(:base_attrs) do
      {
        client_id: application.uid,
        response_type: "code",
        redirect_uri: application.redirect_uri,
        scope: "openid",
        state: "the-state",
      }
    end

    # `client` is resolved during validation, which is also the order the
    # controller uses: it serializes the pre-authorization only once
    # `authorizable?` has passed.
    before { subject.authorizable? }

    context "with a nonce" do
      let(:attrs) { base_attrs.merge(nonce: "123456") }

      it "exposes it alongside the attributes Doorkeeper already serializes" do
        expect(subject.as_json).to include(nonce: "123456", client_id: application.uid, state: "the-state")
      end
    end

    context "without a nonce" do
      let(:attrs) { base_attrs }

      it "omits the key rather than serializing a null" do
        expect(subject.as_json).not_to have_key(:nonce)
      end
    end
  end

  describe "#authorizable? nonce enforcement" do
    let(:application) { create(:application) }
    let(:client) { Doorkeeper::OAuth::Client.new(application) }
    let(:base_attrs) do
      {
        client_id: client.uid,
        redirect_uri: "https://app.com/callback",
        scope: "openid",
      }
    end

    before do
      described_class.reset_implicit_nonce_deprecation_warning!
    end

    shared_examples "an implicit flow requiring nonce" do |response_type|
      subject { Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: response_type)) }

      context "without a nonce" do
        context "when enforce_implicit_nonce is disabled (default)" do
          it "is authorizable for backward compatibility" do
            allow(described_class).to receive(:warn_missing_nonce_deprecation)
            expect(subject).to be_authorizable
          end

          it "emits a deprecation warning" do
            expect(described_class).to receive(:warn_missing_nonce_deprecation)
            subject.authorizable?
          end
        end

        context "when enforce_implicit_nonce is enabled" do
          before do
            allow(Doorkeeper::OpenidConnect.configuration).to receive(:enforce_implicit_nonce).and_return(true)
          end

          it "is not authorizable" do
            expect(subject).not_to be_authorizable
          end

          it "sets missing_param to :nonce" do
            subject.authorizable?
            expect(subject.missing_param).to eq :nonce
          end

          it "does not emit a deprecation warning" do
            expect(described_class).not_to receive(:warn_missing_nonce_deprecation)
            subject.authorizable?
          end
        end
      end

      context "with a nonce" do
        subject { Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: response_type, nonce: "abc123")) }

        it "is authorizable while enforce_implicit_nonce is disabled" do
          expect(subject).to be_authorizable
        end

        it "is authorizable while enforce_implicit_nonce is enabled" do
          allow(Doorkeeper::OpenidConnect.configuration).to receive(:enforce_implicit_nonce).and_return(true)
          expect(subject).to be_authorizable
        end
      end
    end

    it_behaves_like "an implicit flow requiring nonce", "id_token"
    it_behaves_like "an implicit flow requiring nonce", "id_token token"

    it "emits the deprecation warning at most once per process" do
      allow(described_class).to receive(:warn)

      first = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: "id_token"))
      second = Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: "id_token token"))
      first.authorizable?
      second.authorizable?

      expect(described_class).to have_received(:warn).once
    end

    context "with response_type = code (authorization code flow)" do
      subject { Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: "code")) }

      it "is authorizable without a nonce and never enforces nonce" do
        allow(Doorkeeper::OpenidConnect.configuration).to receive(:enforce_implicit_nonce).and_return(true)
        expect(described_class).not_to receive(:warn_missing_nonce_deprecation)
        expect(subject).to be_authorizable
      end
    end
  end

  describe ".invalid_request_error" do
    # Doorkeeper changed how validations record their error mid-5.6: a symbol
    # up to 5.6.7, an error class afterwards. `#error_response` only routes a
    # failure to InvalidRequestResponse when the recorded value matches what
    # that version registers, so the nonce validation has to mirror it rather
    # than guess from the presence of Doorkeeper::Errors::InvalidRequest —
    # 5.6.7 defines that constant while still registering symbols.
    def base_registering(error)
      Class.new do
        define_singleton_method(:validations) do
          [{ attribute: :params, options: { error: error } }]
        end
      end
    end

    it "mirrors a symbol registration (Doorkeeper 5.5.x through 5.6.7)" do
      expect(described_class.invalid_request_error(base_registering(:invalid_request)))
        .to eq(:invalid_request)
    end

    it "mirrors an error class registration (Doorkeeper 5.6.8+)" do
      # A stand-in for Doorkeeper::Errors::InvalidRequest, which does not exist
      # on 5.5.x: what matters is that whatever is registered comes back as-is.
      error_class = Class.new(StandardError)

      expect(described_class.invalid_request_error(base_registering(error_class))).to eq(error_class)
    end

    it "falls back to :invalid_request when no params validation is registered" do
      base = Class.new { define_singleton_method(:validations) { [] } }

      expect(described_class.invalid_request_error(base)).to eq(:invalid_request)
    end

    # The controller path validates more than once, and Doorkeeper's own
    # `validate_client_id` returns `@missing_param.nil?` — stale from the nonce
    # failure — so a second pass overwrites the error with its own
    # `invalid_request` and hides a mismatch. One pass is what an application
    # calling `authorizable?` itself sees, and what actually exercises the
    # registered value.
    it "yields an invalid_request response after a single validation pass" do
      allow(Doorkeeper::OpenidConnect.configuration).to receive(:enforce_implicit_nonce).and_return(true)
      application = create(:application)
      pre_auth = Doorkeeper::OAuth::PreAuthorization.new(
        Doorkeeper.configuration,
        {
          client_id: application.uid,
          redirect_uri: "https://app.com/callback",
          scope: "openid",
          response_type: "id_token token",
        },
      )

      pre_auth.authorizable?

      expect(pre_auth.error_response).to be_a Doorkeeper::OAuth::InvalidRequestResponse
      expect(pre_auth.error_response.body[:error]).to eq :invalid_request
    end

    it "registers the nonce validation with the error the running Doorkeeper uses" do
      validations = Doorkeeper::OAuth::PreAuthorization.validations
      nonce = validations.find { |validation| validation[:attribute] == :nonce }
      params = validations.find { |validation| validation[:attribute] == :params }

      expect(nonce[:options][:error]).to eq(params[:options][:error])
    end
  end

  describe "#error_response" do
    context "with response_type = code" do
      let(:attrs) { { response_type: "code", redirect_uri: "client.com/callback" } }

      it "redirects to redirect_uri with query parameter" do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}\?/)
      end
    end

    context "with response_type = token" do
      let(:attrs) { { response_type: "token", redirect_uri: "client.com/callback" } }

      it "redirects to redirect_uri with fragment" do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end

    context "with response_type = id_token" do
      let(:attrs) { { response_type: "id_token", redirect_uri: "client.com/callback" } }

      it "redirects to redirect_uri with fragment" do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end

    context "with response_type = id_token token" do
      let(:attrs) { { response_type: "id_token token", redirect_uri: "client.com/callback" } }

      it "redirects to redirect_uri with fragment" do
        expect(subject.error_response.redirect_uri).to match(/#{attrs[:redirect_uri]}#/)
      end
    end
  end
end
