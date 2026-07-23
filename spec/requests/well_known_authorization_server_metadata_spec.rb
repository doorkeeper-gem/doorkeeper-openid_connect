# frozen_string_literal: true

require "rails_helper"

# Pins who serves /.well-known/oauth-authorization-server and what it contains.
# On Doorkeeper >= 6.0 the core RFC 8414 route (drawn by `use_doorkeeper`, which
# the dummy app mounts first, mirroring the README order) shadows this gem's
# route at the same path; MetadataExtension enriches that document so the
# takeover is invisible to clients. On older Doorkeeper the request falls
# through to the gem's own discovery route. Either way the served document must
# carry the OIDC issuer and metadata.
describe "RFC 8414 authorization server metadata", type: :request do
  it "serves an OIDC-aware document at /.well-known/oauth-authorization-server" do
    get "/.well-known/oauth-authorization-server"

    expect(response).to have_http_status(:ok)

    data = JSON.parse(response.body)

    expect(data["issuer"]).to eq "dummy"
    expect(data["jwks_uri"]).to end_with("/oauth/discovery/keys")
    expect(data["userinfo_endpoint"]).to end_with("/oauth/userinfo")
    expect(data["id_token_signing_alg_values_supported"]).to eq ["RS256"]
    expect(data["subject_types_supported"]).to eq ["public"]
  end

  it "agrees with the OIDC discovery document on every shared field" do
    get "/.well-known/oauth-authorization-server"
    rfc8414 = JSON.parse(response.body)

    get "/.well-known/openid-configuration"
    oidc = JSON.parse(response.body)

    # `fetch` with a sentinel so a key dropped from one document while the
    # other serves an explicit null (Doorkeeper's core document emits nulls,
    # the discovery document compacts them away) still counts as divergence.
    absent = Object.new
    describe_value = ->(value) { value.equal?(absent) ? "no such key" : value.inspect }

    %w[
      issuer
      authorization_endpoint
      token_endpoint
      revocation_endpoint
      introspection_endpoint
      userinfo_endpoint
      jwks_uri
      scopes_supported
      subject_types_supported
      id_token_signing_alg_values_supported
      claim_types_supported
      claims_supported
    ].each do |field|
      rfc8414_value = rfc8414.fetch(field, absent)
      oidc_value = oidc.fetch(field, absent)

      expect(rfc8414_value).to eq(oidc_value),
                               "#{field} diverged: RFC 8414 document has #{describe_value.call(rfc8414_value)}, " \
                               "OIDC discovery has #{describe_value.call(oidc_value)}"
    end
  end

  it "serves the scoped mount with the OIDC issuer" do
    get "/admins/.well-known/oauth-authorization-server"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["issuer"]).to eq "dummy"
  end
end
