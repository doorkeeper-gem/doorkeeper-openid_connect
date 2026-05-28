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
      let(:rsa_key_1) { OpenSSL::PKey::RSA.generate(2048) }
      let(:rsa_key_2) { OpenSSL::PKey::RSA.generate(2048) }
      let(:rsa_key_1_pem) { rsa_key_1.to_pem }
      let(:rsa_key_2_pem) { rsa_key_2.to_pem }

      before do
        key_pem = rsa_key_1_pem
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
        kid_1 = subject.signing_key.kid

        key_pem = rsa_key_2_pem
        described_class.configure do
          signing_key -> { key_pem }
        end

        kid_2 = subject.signing_key.kid

        expect(kid_1).not_to eq kid_2
      end

      it "returns same kid for same key across multiple calls" do
        kid_1 = subject.signing_key.kid
        kid_2 = subject.signing_key.kid

        expect(kid_1).to eq kid_2
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
    let(:rsa_pem_1) { OpenSSL::PKey::RSA.generate(2048).to_pem }
    let(:rsa_pem_2) { OpenSSL::PKey::RSA.generate(2048).to_pem }

    it "wraps a single configured key into a one-element array" do
      expect(subject.signing_keys.size).to eq 1
      expect(subject.signing_keys.first).to be_a ::JWT::JWK::KeyBase
    end

    context "when signing_key is an array" do
      before do
        keys = [rsa_pem_1, rsa_pem_2]
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
        keys = [rsa_pem_1, rsa_pem_2]
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
        entries = [{ key: rsa_pem_1 }, rsa_pem_2]
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
          .to raise_error(Doorkeeper::OpenidConnect::Errors::InvalidConfiguration,
                          /signing_key must resolve to at least one key/)
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
        subject.signing_key_normalized.merge(use: "sig", alg: :RS256)
      ]
    end

    context "with multiple keys configured" do
      let(:rsa_pem_1) { OpenSSL::PKey::RSA.generate(2048).to_pem }
      let(:rsa_pem_2) { OpenSSL::PKey::RSA.generate(2048).to_pem }

      before do
        keys = [rsa_pem_1, rsa_pem_2]
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
          n: "sjdnSA6UWUQQHf6BLIkIEUhMRNBJC1NN_pFt1EJmEiI88GS0ceROO5B5Ooo9Y3QOWJ_n-u1uwTHBz0HCTN4wgArWd1TcqB5GQzQRP4eYnWyPfi4CfeqAHzQp-v4VwbcK0LW4FqtW5D0dtrFtI281FDxLhARzkhU2y7fuYhL8fVw5rUhE8uwvHRZ5CEZyxf7BSHxIvOZAAymhuzNLATt2DGkDInU1BmF75tEtBJAVLzWG_j4LPZh1EpSdfezqaXQlcy9PJi916UzTl0P7Yy-ulOdUsMlB6yo8qKTY1-AbZ5jzneHbGDU_O8QjYvii1WDmJ60t0jXicmOkGrOhruOptw"
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
          y: "AYJ7GYeBm_Fb6liN53xGASdbRSzF34h4BDSVYzjtQc7I-1LK17fwwS3VfQCJwaT6zX33HTrhR4VoUEUJHKwR3dNs"
        )
      end
    end

    context "when signing key is HMAC" do
      before { configure_hmac }

      it "returns the HMAC public key parameters" do
        expect(subject.signing_key_normalized).to eq(
          kty: "oct",
          kid: "UGyfZX0uOWB46idsQ0QxdFISdaoGilib_t-ZUw8V0Qc"
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
  end
end
