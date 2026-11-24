# frozen_string_literal: true

require "rails_helper"

# `prompt=none` asks for an answer without any interactive UI (OIDC Core
# §3.1.2.1). That is not an answer without consent: wherever Doorkeeper would
# have shown the consent form, the request has to fail with `consent_required`.
#
# Doorkeeper does not accept an earlier token in place of the consent of a
# public client (CVE-2023-34246) — the client's identity cannot be proven, and
# another application may be receiving its redirect URI (RFC 8252 §8.6). From
# v1.10.0 to v2.1.0 `prompt=none` answered in Doorkeeper's place and let such a
# client through.
describe "Authorization requests with prompt=none", type: :request do
  let!(:user) { create :user }
  let(:confidential) { false }
  let(:redirect_uri) { "com.example.app:/oauth/callback" }
  let(:client) do
    create :application, confidential: confidential, redirect_uri: redirect_uri, scopes: "openid profile email"
  end
  let(:granted_scopes) { "openid profile" }
  let(:code_verifier) { SecureRandom.urlsafe_base64(48) }

  before do
    create :access_token, application: client, resource_owner_id: user.id, scopes: granted_scopes
  end

  def authorize(params = {})
    get "/oauth/authorize", params: {
      client_id: client.uid,
      response_type: "code",
      redirect_uri: redirect_uri,
      scope: "openid profile",
      state: "some-state",
      prompt: "none",
      current_user: user.id,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
      code_challenge_method: "S256",
    }.merge(params)
  end

  # What the client is handed back, from the query or from the fragment.
  def authorization_response
    location = URI.parse(response.location)
    Rack::Utils.parse_query(location.query || location.fragment)
  end

  def expect_consent_required!
    expect(response).to have_http_status(:found)
    expect(response.location).to start_with(redirect_uri)
    expect(authorization_response).to include("error" => "consent_required", "state" => "some-state")
    expect(authorization_response.keys).not_to include("code", "access_token", "id_token")
  end

  def expect_authorization_code!
    expect(response).to have_http_status(:found)
    expect(response.location).to start_with(redirect_uri)
    expect(authorization_response).to include("code" => be_present, "state" => "some-state")
    expect(authorization_response).not_to have_key("error")
  end

  context "with a public client" do
    it "requires consent when an earlier token has exactly the requested scopes" do
      expect { authorize }.not_to change(Doorkeeper::AccessGrant, :count)

      expect_consent_required!
    end

    it "requires consent when an earlier token covers more than the requested scopes" do
      expect { authorize(scope: "openid") }.not_to change(Doorkeeper::AccessGrant, :count)

      expect_consent_required!
    end

    it "requires consent when the earlier token has expired" do
      Doorkeeper::AccessToken.update_all(created_at: 1.day.ago, expires_in: 60)

      expect { authorize }.not_to change(Doorkeeper::AccessGrant, :count)

      expect_consent_required!
    end

    it "requires consent on the implicit flow, without issuing tokens" do
      expect { authorize(response_type: "id_token token", nonce: "some-nonce") }
        .not_to change(Doorkeeper::AccessToken, :count)

      expect(URI.parse(response.location).fragment).to be_present
      expect_consent_required!
    end

    # The host application's own decision is not second-guessed: a client it
    # exempts from consent never sees the consent form, with or without
    # `prompt=none`.
    it "answers with a code when skip_authorization covers the client" do
      allow(Doorkeeper.configuration).to receive(:skip_authorization).and_return(->(*) { true })

      expect { authorize }.to change(Doorkeeper::AccessGrant, :count).by(1)

      expect_authorization_code!
    end
  end

  context "with a confidential client" do
    let(:confidential) { true }

    it "answers with a code when an earlier token has exactly the requested scopes" do
      expect { authorize }.to change(Doorkeeper::AccessGrant, :count).by(1)

      expect_authorization_code!
    end

    # Issue #63.
    it "answers with a code when an earlier token covers more than the requested scopes" do
      expect { authorize(scope: "openid") }.to change(Doorkeeper::AccessGrant, :count).by(1)

      expect_authorization_code!
    end

    it "requires consent when no earlier token covers the requested scopes" do
      expect { authorize(scope: "openid email") }.not_to change(Doorkeeper::AccessGrant, :count)

      expect_consent_required!
    end

    it "requires consent once the earlier token is revoked" do
      Doorkeeper::AccessToken.update_all(revoked_at: Time.current)

      expect { authorize }.not_to change(Doorkeeper::AccessGrant, :count)

      expect_consent_required!
    end

    # Doorkeeper >= 5.7 does not accept an earlier token in place of consent
    # once custom attributes are configured: the earlier token may have been
    # issued for other values of them than this request carries.
    context "when custom access token attributes are configured",
            if: Doorkeeper::AuthorizationsController.private_method_defined?(:can_authorize_response?) do
      before do
        allow(Doorkeeper.configuration)
          .to receive(:custom_access_token_attributes).and_return([:tenant_name])
      end

      it "requires consent" do
        expect { authorize }.not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end
    end

    # Issue #63 on the implicit flow: the wider-scope match has to reach
    # Doorkeeper's auto-issue path there too, and issue the tokens.
    it "answers with tokens on the implicit flow when an earlier token covers more than the requested scopes" do
      expect { authorize(response_type: "id_token token", scope: "openid", nonce: "some-nonce") }
        .to change(Doorkeeper::AccessToken, :count).by(1)

      expect(URI.parse(response.location).fragment).to be_present
      expect(authorization_response)
        .to include("access_token" => be_present, "id_token" => be_present, "state" => "some-state")
      expect(authorization_response).not_to have_key("error")
    end

    # Doorkeeper 6.0 does not accept an earlier token in place of the consent
    # of a client known only from its metadata document, confidential or not:
    # anyone can publish one. Such a client turns confidential when its
    # document declares private_key_jwt and this server offers it, so the
    # client type alone does not stop it.
    #
    # Only the fetch of the document is stubbed: Doorkeeper resolves the
    # client_id and writes the application row itself. The columns come from
    # Doorkeeper's client_id_metadata_documents generator and from the host
    # (jwks_uri); they are added inside the example's transaction, so the
    # rollback takes them away again.
    context "when the client is known only from its metadata document",
            if: defined?(Doorkeeper::OAuth::ClientIdMetadataDocument) do
      let(:client_id) { "https://client.example.com/oauth/metadata.json" }
      let(:redirect_uri) { "https://client.example.com/oauth/callback" }

      before do
        connection = ActiveRecord::Base.connection
        connection.add_column :oauth_applications, Doorkeeper::OAuth::ClientIdMetadataDocument::MARKER, :datetime
        connection.add_column :oauth_applications, :jwks_uri, :string
        Doorkeeper::Application.reset_column_information

        allow(Doorkeeper.configuration).to receive_messages(
          use_client_id_metadata_documents?: true,
          client_authentication_methods: %i[client_secret_basic none private_key_jwt].map do |name|
            Doorkeeper::ClientAuthentication.get(name)
          end,
        )
        fetcher = instance_double(Doorkeeper::HttpFetcher)
        allow(Doorkeeper::HttpFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).with(client_id).and_return({
          client_id: client_id,
          client_name: "Example",
          redirect_uris: [redirect_uri],
          scope: "openid profile email",
          token_endpoint_auth_methods_supported: %w[none private_key_jwt],
          jwks_uri: "https://client.example.com/oauth/jwks.json",
        }.to_json)

        create :access_token, application: Doorkeeper::OAuth::ClientIdMetadataDocument.application(client_id),
                              resource_owner_id: user.id, scopes: granted_scopes
      end

      after do
        Doorkeeper::OAuth::ClientIdMetadataDocument.cache.clear
        Doorkeeper::Application.reset_column_information
      end

      it "is a confidential client known from its document" do
        application = Doorkeeper::Application.by_uid(client_id)

        expect(application).to be_confidential
        expect(Doorkeeper::OAuth::ClientIdMetadataDocument).to be_materialized(application)
      end

      it "requires consent when an earlier token has exactly the requested scopes" do
        expect { authorize(client_id: client_id) }.not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end

      it "requires consent when an earlier token covers more than the requested scopes" do
        expect { authorize(client_id: client_id, scope: "openid") }.not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end
    end

    # RFC 8707 (Doorkeeper >= 6.0): an earlier token issued for another
    # `resource` does not stand in for consent, whatever its scopes. The
    # `resource` columns come from Doorkeeper's resource_indicators generator
    # and are added inside the example's transaction, as above.
    context "when the earlier token was issued for a resource",
            if: Doorkeeper.config.access_token_model.respond_to?(:resource_indicators_match?) do
      let(:resource) { "https://api.example.com" }

      before do
        ActiveRecord::Base.connection.add_column :oauth_access_tokens, :resource, :text
        ActiveRecord::Base.connection.add_column :oauth_access_grants, :resource, :text
        Doorkeeper::AccessToken.reset_column_information
        Doorkeeper::AccessGrant.reset_column_information
        Doorkeeper::AccessToken.update_all(resource: resource)
        allow(Doorkeeper.configuration).to receive(:resource_indicator_validator).and_return(->(*) { true })
      end

      after do
        Doorkeeper::AccessToken.reset_column_information
        Doorkeeper::AccessGrant.reset_column_information
      end

      it "answers with a code when the request names the same resource and fewer scopes" do
        expect { authorize(scope: "openid", resource: resource) }.to change(Doorkeeper::AccessGrant, :count).by(1)

        expect_authorization_code!
      end

      it "requires consent when the request names another resource" do
        expect { authorize(resource: "https://other.example.com") }.not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end

      it "requires consent when the request names another resource and fewer scopes" do
        expect { authorize(scope: "openid", resource: "https://other.example.com") }
          .not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end

      it "requires consent when the request names no resource and fewer scopes" do
        expect { authorize(scope: "openid") }.not_to change(Doorkeeper::AccessGrant, :count)

        expect_consent_required!
      end
    end
  end
end
