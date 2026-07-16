# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect do
  describe ".signing_algorithm" do
    it "returns the signing_algorithm as an uppercase symbol" do
      expect(subject.signing_algorithm).to eq :RS256
    end
  end

  describe ".signing_key" do
    it "returns the private key as JWK instance" do
      expect(subject.signing_key).to be_a ::JWT::JWK::KeyBase
      expect(subject.signing_key.kid).to eq "IqYwZo2cE6hsyhs48cU8QHH4GanKIx0S4Dc99kgTIMA"
    end

    context "when signing_key is callable with RSA key" do
      let(:rsa_key1) { OpenSSL::PKey::RSA.generate(2048) }
      let(:rsa_key2) { OpenSSL::PKey::RSA.generate(2048) }
      let(:rsa_key1_pem) { rsa_key1.to_pem }
      let(:rsa_key2_pem) { rsa_key2.to_pem }

      before do
        key_pem = rsa_key1_pem
        described_class.configure do
          signing_key -> { key_pem }
        end
      end

      it "returns a JWK instance" do
        expect(subject.signing_key).to be_a ::JWT::JWK::KeyBase
      end

      it "generates correct key type" do
        expect(subject.signing_key_normalized[:kty]).to eq "RSA"
      end

      it "generates valid kid" do
        expect(subject.signing_key.kid).not_to be_nil
        expect(subject.signing_key.kid).to be_a String
        expect(subject.signing_key.kid.length).to be > 0
      end

      it "generates different kids for different keys" do
        kid1 = subject.signing_key.kid

        key_pem = rsa_key2_pem
        described_class.configure do
          signing_key -> { key_pem }
        end

        kid2 = subject.signing_key.kid

        expect(kid1).not_to eq kid2
      end

      it "returns same kid for same key across multiple calls" do
        kid1 = subject.signing_key.kid
        kid2 = subject.signing_key.kid

        expect(kid1).to eq kid2
      end

      it "can be used for JWT signing" do
        jwk = subject.signing_key
        payload = { sub: "123", iat: Time.now.to_i }

        token = JWT.encode(payload, jwk.keypair, "RS256", kid: jwk.kid)

        expect(token).not_to be_nil
        expect(token).to be_a String
      end
    end

    context "when signing_key is callable with EC key" do
      let(:ec_key) do
        OpenSSL::PKey::EC.generate("prime256v1")
      end
      let(:ec_key_pem) { ec_key.to_pem }

      before do
        key_pem = ec_key_pem
        described_class.configure do
          signing_algorithm :ES256
          signing_key -> { key_pem }
        end
      end

      it "returns a JWK instance" do
        expect(subject.signing_key).to be_a ::JWT::JWK::KeyBase
      end

      it "generates correct key type" do
        expect(subject.signing_key_normalized[:kty]).to eq "EC"
      end

      it "generates valid kid" do
        expect(subject.signing_key.kid).not_to be_nil
        expect(subject.signing_key.kid).to be_a String
      end
    end

    context "when signing_key is callable with HMAC key" do
      let(:hmac_secret) { "dynamic_hmac_secret_key_for_testing" }

      before do
        secret = hmac_secret
        described_class.configure do
          signing_algorithm :HS256
          signing_key -> { secret }
        end
      end

      it "returns a JWK instance" do
        expect(subject.signing_key).to be_a ::JWT::JWK::KeyBase
      end

      it "generates correct key type" do
        expect(subject.signing_key_normalized[:kty]).to eq "oct"
      end

      it "generates valid kid" do
        expect(subject.signing_key.kid).not_to be_nil
        expect(subject.signing_key.kid).to be_a String
      end
    end

    context "when signing_key is an array with an unparseable trailing entry" do
      let(:rsa_pem) { OpenSSL::PKey::RSA.generate(2048).to_pem }

      before do
        entries = [rsa_pem, "not-a-valid-pem"]
        described_class.configure do
          signing_key entries
        end
      end

      it "builds only the active entry on the ID token signing hot path" do
        expect { subject.signing_key }.not_to raise_error
        expect { subject.signing_keys }.to raise_error(OpenSSL::PKey::PKeyError)
      end
    end
  end

  describe ".signing_keys" do
    let(:rsa_pem1) { OpenSSL::PKey::RSA.generate(2048).to_pem }
    let(:rsa_pem2) { OpenSSL::PKey::RSA.generate(2048).to_pem }

    it "wraps a single configured key into a one-element array" do
      expect(subject.signing_keys.size).to eq 1
      expect(subject.signing_keys.first).to be_a ::JWT::JWK::KeyBase
    end

    context "when signing_key is an array" do
      before do
        keys = [rsa_pem1, rsa_pem2]
        described_class.configure do
          signing_key keys
        end
      end

      it "returns one JWK per array element, preserving order" do
        expect(subject.signing_keys.size).to eq 2
        expect(subject.signing_keys).to all(be_a(::JWT::JWK::KeyBase))
      end

      it "uses the first entry as the active signing key" do
        expect(subject.signing_key.kid).to eq subject.signing_keys.first.kid
      end

      it "produces distinct kids for distinct keys" do
        kids = subject.signing_keys.map(&:kid)
        expect(kids.uniq).to eq kids
      end
    end

    context "when signing_key is a callable returning an array" do
      before do
        keys = [rsa_pem1, rsa_pem2]
        described_class.configure do
          signing_key -> { keys }
        end
      end

      it "evaluates the callable and expands the array" do
        expect(subject.signing_keys.size).to eq 2
      end
    end

    context "when signing_key is an array with a Hash entry (forward-compat)" do
      before do
        entries = [{ key: rsa_pem1 }, rsa_pem2]
        described_class.configure do
          signing_key entries
        end
      end

      it "normalizes Hash and bare-string entries uniformly" do
        expect(subject.signing_keys.size).to eq 2
        expect(subject.signing_keys).to all(be_a(::JWT::JWK::KeyBase))
      end
    end

    context "when signing_key resolves to an empty array" do
      it "raises InvalidConfiguration for an empty array literal" do
        described_class.configure do
          signing_key []
        end

        expect { subject.signing_keys }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration, /signing_key must resolve to at least one key/)
        expect { subject.signing_key }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration)
      end

      it "raises InvalidConfiguration for a callable returning an empty array" do
        described_class.configure do
          signing_key -> { [] }
        end

        expect { subject.signing_keys }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration)
      end
    end
  end

  describe ".signing_keys_normalized" do
    it "merges use and alg into each exported key" do
      expect(subject.signing_keys_normalized).to eq [
        subject.signing_key_normalized.merge(use: "sig", alg: :RS256),
      ]
    end

    context "with multiple keys configured" do
      let(:rsa_pem1) { OpenSSL::PKey::RSA.generate(2048).to_pem }
      let(:rsa_pem2) { OpenSSL::PKey::RSA.generate(2048).to_pem }

      before do
        keys = [rsa_pem1, rsa_pem2]
        described_class.configure do
          signing_key keys
        end
      end

      it "returns one normalized entry per configured key" do
        normalized = subject.signing_keys_normalized
        expect(normalized.size).to eq 2
        expect(normalized).to all(include(use: "sig", alg: :RS256))
      end
    end
  end

  describe ".signing_key_normalized" do
    context "when signing key is RSA" do
      it "returns the RSA public key parameters" do
        expect(subject.signing_key_normalized).to eq(
          kty: "RSA",
          kid: "IqYwZo2cE6hsyhs48cU8QHH4GanKIx0S4Dc99kgTIMA",
          e: "AQAB",
          n: "sjdnSA6UWUQQHf6BLIkIEUhMRNBJC1NN_pFt1EJmEiI88GS0ceROO5B5Ooo9Y3QOWJ_n-u1uwTHBz0HCTN4wgArWd1TcqB5GQzQRP4eYnWyPfi4CfeqAHzQp-v4VwbcK0LW4FqtW5D0dtrFtI281FDxLhARzkhU2y7fuYhL8fVw5rUhE8uwvHRZ5CEZyxf7BSHxIvOZAAymhuzNLATt2DGkDInU1BmF75tEtBJAVLzWG_j4LPZh1EpSdfezqaXQlcy9PJi916UzTl0P7Yy-ulOdUsMlB6yo8qKTY1-AbZ5jzneHbGDU_O8QjYvii1WDmJ60t0jXicmOkGrOhruOptw",
        )
      end
    end

    context "when signing key is EC" do
      before { configure_ec }

      it "returns the EC public key parameters" do
        expect(subject.signing_key_normalized).to eq(
          kty: "EC",
          kid: "dOx_AhaepicN2r2M-sxZhgkYZMCX7dYhPsNOw1ZiFnI",
          crv: "P-521",
          x: "AeYVvbl3zZcFCdE-0msqOowYODjzeXAhjsZKhdNjGlDREvko3UFOw6S43g-s8bvVBmBz3fCodEzFRYQqJVI4UFvF",
          y: "AYJ7GYeBm_Fb6liN53xGASdbRSzF34h4BDSVYzjtQc7I-1LK17fwwS3VfQCJwaT6zX33HTrhR4VoUEUJHKwR3dNs",
        )
      end
    end

    context "when signing key is HMAC" do
      before { configure_hmac }

      it "returns the HMAC public key parameters" do
        expect(subject.signing_key_normalized).to eq(
          kty: "oct",
          kid: "UGyfZX0uOWB46idsQ0QxdFISdaoGilib_t-ZUw8V0Qc",
        )
      end
    end
  end

  describe "registering grant flows" do
    describe Doorkeeper::Request do
      it 'uses the correct strategy for "id_token" response types' do
        expect(described_class.authorization_strategy("id_token")).to eq(Doorkeeper::Request::IdToken)
      end

      it 'uses the correct strategy for "id_token token" response types' do
        expect(described_class.authorization_strategy("id_token token")).to eq(Doorkeeper::Request::IdTokenToken)
      end
    end
  end

  describe ".configure issuer consistency (RFC 9207)" do
    # `Doorkeeper.config.issuer` only exists on Doorkeeper builds shipping
    # doorkeeper-gem/doorkeeper#1838, so the seam `doorkeeper_issuer` is
    # stubbed instead of the real config (mirroring the fallback specs'
    # rationale: a partial double on the real config would be rejected on
    # released Doorkeeper versions).
    # Spy style (have_received asserted inside the example body) rather than
    # message expectations: the rails_helper `config.after` hook reinitializes
    # the configuration while the doorkeeper_issuer stub is still active, so a
    # message expectation would also count that teardown-time configure call.
    before do
      allow(Rails.logger).to receive(:warn)
    end

    it "warns when the OpenID Connect and Doorkeeper issuers are both set and differ" do
      allow(described_class).to receive(:doorkeeper_issuer)
        .and_return("https://doorkeeper-issuer.example.com")

      described_class.configure do
        issuer "https://oidc-issuer.example.com"
      end

      expect(Rails.logger).to have_received(:warn).with(/differs from Doorkeeper's issuer/)
    end

    it "does not warn when both issuers match" do
      allow(described_class).to receive(:doorkeeper_issuer)
        .and_return("https://issuer.example.com")

      described_class.configure do
        issuer "https://issuer.example.com"
      end

      expect(Rails.logger).not_to have_received(:warn).with(/differs from Doorkeeper's issuer/)
    end

    it "does not warn when Doorkeeper has no issuer" do
      allow(described_class).to receive(:doorkeeper_issuer).and_return(nil)

      described_class.configure do
        issuer "https://oidc-issuer.example.com"
      end

      expect(Rails.logger).not_to have_received(:warn).with(/differs from Doorkeeper's issuer/)
    end

    it "does not warn for a callable OpenID Connect issuer" do
      allow(described_class).to receive(:doorkeeper_issuer)
        .and_return("https://doorkeeper-issuer.example.com")

      described_class.configure do
        issuer { |_resource_owner, _application| "https://oidc-issuer.example.com" }
      end

      expect(Rails.logger).not_to have_received(:warn).with(/differs from Doorkeeper's issuer/)
    end

    it "does not warn when Doorkeeper is not yet configured" do
      # No doorkeeper_issuer stub here: the real method must short-circuit on
      # the doorkeeper_configured? guard and read as nil.
      allow(described_class).to receive(:doorkeeper_configured?).and_return(false)

      described_class.configure do
        issuer "https://oidc-issuer.example.com"
      end

      expect(Rails.logger).not_to have_received(:warn).with(/differs from Doorkeeper's issuer/)
    end
  end

  describe ".doorkeeper_issuer" do
    # `Doorkeeper.configured?` does not exist on Doorkeeper 5.5 and
    # `Doorkeeper.config.issuer` only exists on builds shipping
    # doorkeeper-gem/doorkeeper#1838, so both sides are stubbed through the
    # gem's own seams to stay version-portable.
    context "when Doorkeeper is not yet configured" do
      before do
        allow(described_class).to receive(:doorkeeper_configured?).and_return(false)
        allow(Doorkeeper).to receive(:config).and_call_original
      end

      it "returns nil without reading Doorkeeper's config" do
        expect(described_class.doorkeeper_issuer).to be_nil
        expect(Doorkeeper).not_to have_received(:config)
      end
    end

    context "when Doorkeeper is configured" do
      before do
        allow(described_class).to receive(:doorkeeper_configured?).and_return(true)
      end

      it "returns Doorkeeper's issuer when the option exists" do
        allow(Doorkeeper.config).to receive(:try).and_call_original
        allow(Doorkeeper.config).to receive(:try)
          .with(:issuer)
          .and_return("https://doorkeeper-issuer.example.com")

        expect(described_class.doorkeeper_issuer).to eq "https://doorkeeper-issuer.example.com"
      end

      it "returns nil when Doorkeeper exposes no issuer" do
        # Released Doorkeeper versions predate `config.issuer` (`try` returns
        # nil); on builds that ship it the dummy app leaves it unset — nil
        # either way, keeping this example version-portable.
        expect(described_class.doorkeeper_issuer).to be_nil
      end
    end
  end

  describe ".resolve_issuer" do
    let(:resource_owner) { double("ResourceOwner") }
    let(:application) { double("Application") }
    let(:request) { double("Request", base_url: "https://example.com") }

    context "when issuer is a static string" do
      before do
        described_class.configure do
          issuer "https://static-issuer.example.com"
        end
      end

      it "returns the static string" do
        expect(subject.resolve_issuer).to eq "https://static-issuer.example.com"
      end
    end

    context "when issuer block has arity 0" do
      before do
        described_class.configure do
          issuer do
            "https://zero-arity.example.com"
          end
        end
      end

      it "calls the block without arguments" do
        expect(subject.resolve_issuer).to eq "https://zero-arity.example.com"
      end
    end

    context "when issuer block has arity 1" do
      before do
        req = request
        owner = resource_owner
        described_class.configure do
          issuer do |request_or_owner|
            if request_or_owner.equal?(req)
              "issuer-request"
            elsif request_or_owner.equal?(owner)
              "issuer-resource-owner"
            else
              "issuer-unknown"
            end
          end
        end
      end

      it "passes request when called from discovery context" do
        result = subject.resolve_issuer(request: request)
        expect(result).to eq "issuer-request"
      end

      it "passes resource_owner when called from token context" do
        result = subject.resolve_issuer(resource_owner: resource_owner)
        expect(result).to eq "issuer-resource-owner"
      end

      it "prefers request over resource_owner when both are present" do
        result = subject.resolve_issuer(resource_owner: resource_owner, request: request)
        expect(result).to eq "issuer-request"
      end
    end

    context "when issuer block has arity 2" do
      before do
        described_class.configure do
          issuer do |resource_owner, application|
            "owner-#{resource_owner&.class&.name}-app-#{application&.class&.name}"
          end
        end
      end

      it "passes resource_owner and application" do
        result = subject.resolve_issuer(resource_owner: resource_owner, application: application)
        expect(result.scan("RSpec::Mocks::Double").size).to eq 2
      end

      it "passes nils from discovery context" do
        result = subject.resolve_issuer(request: request)
        expect(result).to eq "owner--app-"
      end
    end

    context "when issuer block has arity 3" do
      before do
        described_class.configure do
          issuer do |resource_owner, _application, request|
            if request
              request.base_url
            else
              "owner-#{resource_owner&.class&.name}"
            end
          end
        end
      end

      it "passes all three arguments from discovery context" do
        result = subject.resolve_issuer(request: request)
        expect(result).to eq "https://example.com"
      end

      it "passes all three arguments from token context" do
        result = subject.resolve_issuer(resource_owner: resource_owner, application: application)
        expect(result).to include "RSpec::Mocks::Double"
      end

      it "passes all three arguments when all are present" do
        result = subject.resolve_issuer(resource_owner: resource_owner, application: application, request: request)
        expect(result).to eq "https://example.com"
      end
    end

    context "when the OpenID Connect issuer is unset and Doorkeeper has an issuer" do
      # `Doorkeeper.config.issuer` only exists on Doorkeeper builds shipping
      # doorkeeper-gem/doorkeeper#1838, so no released version implements it and
      # a partial double on the real config would be rejected. Stub the gem's
      # own `doorkeeper_issuer` seam instead — it isolates the fallback from the
      # Doorkeeper version and avoids replacing `Doorkeeper.config` wholesale
      # (which leaks into the per-example config reload and breaks on 5.5).
      before do
        described_class.configure {}
        allow(described_class).to receive(:doorkeeper_issuer).and_return("https://doorkeeper-issuer.example.com")
      end

      it "falls back to the Doorkeeper issuer" do
        expect(subject.resolve_issuer).to eq "https://doorkeeper-issuer.example.com"
      end

      it "falls back to the Doorkeeper issuer in the discovery context" do
        expect(subject.resolve_issuer(request: request)).to eq "https://doorkeeper-issuer.example.com"
      end
    end

    context "when the OpenID Connect issuer is set and Doorkeeper also has an issuer" do
      before do
        described_class.configure do
          issuer "https://oidc-issuer.example.com"
        end
        allow(described_class).to receive(:doorkeeper_issuer).and_call_original
      end

      it "prefers the OpenID Connect issuer for backward compatibility" do
        expect(subject.resolve_issuer).to eq "https://oidc-issuer.example.com"
      end

      it "never consults the Doorkeeper issuer" do
        subject.resolve_issuer
        expect(described_class).not_to have_received(:doorkeeper_issuer)
      end
    end

    context "when neither the OpenID Connect nor the Doorkeeper issuer is set" do
      before do
        described_class.configure {}
        allow(described_class).to receive(:doorkeeper_issuer).and_return(nil)
      end

      it "preserves the existing InvalidConfiguration behavior" do
        expect { subject.resolve_issuer(request: request) }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration)
      end
    end

    context "when the installed Doorkeeper has no issuer option" do
      # Emulate a Doorkeeper version that predates `config.issuer` (i.e. before
      # the release shipping doorkeeper-gem/doorkeeper#1838): force the real
      # config to report it does not respond to `issuer`, so the fallback's
      # `respond_to?` guard must skip it rather than blow up. Stubbing only
      # `respond_to?(:issuer)` (instead of replacing `Doorkeeper.config`) keeps
      # this working across Doorkeeper versions, including 5.5 where the
      # per-example config reload would otherwise hit a bare double.
      before do
        described_class.configure {}
        allow(Doorkeeper.config).to receive(:respond_to?).and_call_original
        allow(Doorkeeper.config).to receive(:respond_to?).with(:issuer).and_return(false)
      end

      it "does not call a missing issuer method and raises InvalidConfiguration" do
        expect(Doorkeeper.config).not_to respond_to(:issuer)
        expect { subject.resolve_issuer(request: request) }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration)
      end
    end

    context "when issuer resolves to a blank value" do
      it "raises InvalidConfiguration for a block returning nil in the discovery context" do
        described_class.configure do
          issuer do |resource_owner, application|
            resource_owner && application && "https://example.com"
          end
        end

        expect { subject.resolve_issuer(request: request) }
          .to raise_error(
            Doorkeeper::OpenidConnect::Errors::InvalidConfiguration,
            /issuer must resolve to a non-blank value/,
          )
      end

      it "raises InvalidConfiguration for a blank static value" do
        described_class.configure do
          issuer "  "
        end

        expect { subject.resolve_issuer }
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration)
      end
    end
  end
end
