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

    shared_examples "an implicit/hybrid flow requiring nonce" do |response_type|
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

    it_behaves_like "an implicit/hybrid flow requiring nonce", "id_token"
    it_behaves_like "an implicit/hybrid flow requiring nonce", "id_token token"

    context "with response_type = code (authorization code flow)" do
      subject { Doorkeeper::OAuth::PreAuthorization.new(server, base_attrs.merge(response_type: "code")) }

      it "is authorizable without a nonce and never enforces nonce" do
        allow(Doorkeeper::OpenidConnect.configuration).to receive(:enforce_implicit_nonce).and_return(true)
        expect(described_class).not_to receive(:warn_missing_nonce_deprecation)
        expect(subject).to be_authorizable
      end
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
