# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::BackchannelLogout do
  let(:user) { create :user }
  let(:application) do
    create :application, backchannel_logout_uri: "https://rp.example.com/backchannel-logout"
  end

  # Captures every request the module would send instead of performing real
  # HTTP: `Net::HTTP.new` returns a double whose `start` yields a session
  # recording each `request` call into `sent_requests`.
  let(:sent_requests) { [] }
  let(:response_code) { "200" }

  before do
    http_session = instance_double(Net::HTTP)
    allow(http_session).to receive(:request) do |request|
      sent_requests << request
      instance_double(Net::HTTPResponse, code: response_code)
    end

    http = instance_double(Net::HTTP, "use_ssl=": nil, "open_timeout=": nil, "read_timeout=": nil)
    allow(http).to receive(:start).and_yield(http_session)
    allow(Net::HTTP).to receive(:new).and_return(http)
  end

  def logout_token_from(request)
    encoded = URI.decode_www_form(request.body).to_h.fetch("logout_token")
    algorithms = [Doorkeeper::OpenidConnect.signing_algorithm.to_s]
    ::JWT.decode(encoded, Doorkeeper::OpenidConnect.signing_key.keypair, true, { algorithms: algorithms })
  end

  describe ".notify" do
    context "when the user has an access token for a registered client" do
      before do
        create :access_token, resource_owner_id: user.id, application: application
      end

      it "POSTs a signed Logout Token to the registered backchannel_logout_uri" do
        results = described_class.notify(user)

        expect(results.size).to eq 1
        expect(results.first).to be_delivered
        expect(results.first.status).to eq 200
        expect(results.first.application).to eq application
        expect(results.first.uri).to eq "https://rp.example.com/backchannel-logout"

        expect(Net::HTTP).to have_received(:new).with("rp.example.com", 443)

        request = sent_requests.sole
        expect(request).to be_a(Net::HTTP::Post)
        expect(request.path).to eq "/backchannel-logout"
        expect(request["Content-Type"]).to eq "application/x-www-form-urlencoded"

        claims, headers = logout_token_from(request)
        expect(headers["typ"]).to eq "logout+jwt"
        expect(claims["iss"]).to eq "dummy"
        expect(claims["sub"]).to eq user.id.to_s
        expect(claims["aud"]).to eq application.uid
        expect(claims["events"]).to eq("http://schemas.openid.net/event/backchannel-logout" => {})
        expect(claims).not_to have_key("sid")
        expect(claims).not_to have_key("nonce")
      end

      it "issues a distinct jti per delivery" do
        described_class.notify(user)
        described_class.notify(user)

        jtis = sent_requests.map { |request| logout_token_from(request).first.fetch("jti") }
        expect(jtis.uniq.size).to eq 2
      end

      context "when the RP rejects the Logout Token" do
        let(:response_code) { "400" }

        it "reports the failure status without raising" do
          results = described_class.notify(user)

          expect(results.first).not_to be_delivered
          expect(results.first.status).to eq 400
          expect(results.first.error).to be_nil
        end
      end
    end

    context "when the user only has an access grant for the client" do
      before do
        create :access_grant, resource_owner_id: user.id, application: application
      end

      it "still notifies the client" do
        results = described_class.notify(user)

        expect(results.size).to eq 1
        expect(results.first).to be_delivered
      end
    end

    context "when the client never received a token or grant for the user" do
      before do
        application
        create :access_token, application: application # different resource owner
      end

      it "does not notify the client" do
        expect(described_class.notify(user)).to be_empty
        expect(sent_requests).to be_empty
      end
    end

    context "when the client has no backchannel_logout_uri" do
      before do
        create :access_token, resource_owner_id: user.id
      end

      it "does not notify the client" do
        expect(described_class.notify(user)).to be_empty
        expect(sent_requests).to be_empty
      end
    end

    context "when one delivery fails" do
      let(:other_application) do
        create :application, backchannel_logout_uri: "https://other-rp.example.com/backchannel-logout"
      end

      before do
        create :access_token, resource_owner_id: user.id, application: application
        create :access_token, resource_owner_id: user.id, application: other_application

        failing = instance_double(Net::HTTP, "use_ssl=": nil, "open_timeout=": nil, "read_timeout=": nil)
        allow(failing).to receive(:start).and_raise(Net::OpenTimeout)
        allow(Net::HTTP).to receive(:new).with("rp.example.com", 443).and_return(failing)

        allow(Rails.logger).to receive(:warn)
      end

      it "captures the error, logs a warning and still notifies the remaining clients" do
        results = described_class.notify(user)

        expect(results.size).to eq 2

        failed = results.find { |result| result.application == application }
        expect(failed).not_to be_delivered
        expect(failed.error).to be_a(Net::OpenTimeout)

        succeeded = results.find { |result| result.application == other_application }
        expect(succeeded).to be_delivered

        expect(Rails.logger).to have_received(:warn).with(/Back-channel logout delivery/)
      end
    end

    context "when the application model does not have the backchannel_logout_uri column" do
      before do
        allow(Doorkeeper.config.application_model).to receive(:column_names)
          .and_return(Doorkeeper::Application.column_names - ["backchannel_logout_uri"])
      end

      it "notifies nobody" do
        expect(described_class.notify(user)).to be_empty
      end
    end

    context "when applications are passed explicitly" do
      it "notifies them regardless of issued tokens, skipping entries without a logout URI" do
        without_uri = create :application

        results = described_class.notify(user, applications: [application, without_uri])

        expect(results.size).to eq 1
        expect(results.first.application).to eq application
      end
    end
  end

  describe ".deliver" do
    it "preserves the registered URI's port, path and query" do
      application.update!(backchannel_logout_uri: "https://rp.internal:8080/logout?tenant=42")

      result = described_class.deliver(user, application)

      expect(result).to be_delivered
      expect(Net::HTTP).to have_received(:new).with("rp.internal", 8080)

      request = sent_requests.sole
      expect(request.path).to eq "/logout?tenant=42"
    end
  end
end
