# frozen_string_literal: true

require "rails_helper"

describe Doorkeeper::OpenidConnect::Orm::ActiveRecord::Mixins::Application do
  subject { create(:application) }

  it "extends the base doorkeeper Application" do
    expect(subject).to respond_to(:post_logout_redirect_uris)
    expect(subject).to respond_to(:valid_post_logout_redirect_uri?)
  end

  describe "#post_logout_redirect_uris" do
    it "returns an empty array when not set" do
      expect(subject.post_logout_redirect_uris).to eq([])
    end

    it "returns an array of URIs when set as a string" do
      subject.update!(post_logout_redirect_uris: "https://example.com/logout\nhttps://example.com/logout2")
      expect(subject.post_logout_redirect_uris).to eq(%w[https://example.com/logout https://example.com/logout2])
    end

    it "accepts an array and stores URIs as newline-separated string" do
      uris = ["https://example.com/logout", "https://example.com/logout2"]
      subject.post_logout_redirect_uris = uris
      subject.save!
      subject.reload
      expect(subject.post_logout_redirect_uris).to eq(uris)
    end

    it "returns an empty array when the column has not been added yet" do
      # An existing installation that upgraded the gem without running the
      # add_post_logout_redirect_uris migration.
      allow(subject).to receive(:has_attribute?).and_call_original
      allow(subject).to receive(:has_attribute?).with(:post_logout_redirect_uris).and_return(false)

      expect(subject.post_logout_redirect_uris).to eq([])
      expect(subject.valid_post_logout_redirect_uri?("https://example.com/logout")).to be false
    end
  end

  describe "post_logout_redirect_uris validation" do
    # The attribute is validated by delegating to Doorkeeper's own
    # RedirectUriValidator, so the rules match `redirect_uri` exactly.
    it "is valid when blank (registration is optional)" do
      subject.post_logout_redirect_uris = nil
      expect(subject).to be_valid
      subject.post_logout_redirect_uris = []
      expect(subject).to be_valid
    end

    it "is valid for one or more absolute https URIs" do
      subject.post_logout_redirect_uris = ["https://example.com/logout", "https://example.com/logout2"]
      expect(subject).to be_valid
    end

    it "rejects a forbidden/opaque scheme such as javascript:" do
      subject.post_logout_redirect_uris = ["javascript:alert(1)"]
      expect(subject).not_to be_valid
      expect(subject.errors[:post_logout_redirect_uris]).to be_present
    end

    it "rejects a URI containing a fragment" do
      subject.post_logout_redirect_uris = ["https://example.com/logout#section"]
      expect(subject).not_to be_valid
      expect(subject.errors[:post_logout_redirect_uris]).to be_present
    end

    it "rejects a relative URI" do
      subject.post_logout_redirect_uris = ["/relative/path"]
      expect(subject).not_to be_valid
      expect(subject.errors[:post_logout_redirect_uris]).to be_present
    end

    context "when force_ssl_in_redirect_uri is enabled" do
      before do
        Doorkeeper.configure do
          orm :active_record
          force_ssl_in_redirect_uri true
        end
      end

      it "rejects a plaintext http URI" do
        subject.post_logout_redirect_uris = ["http://example.com/logout"]
        expect(subject).not_to be_valid
        expect(subject.errors[:post_logout_redirect_uris]).to be_present
      end
    end

    it "rejects the whole value when any one URI is invalid" do
      subject.post_logout_redirect_uris = ["https://example.com/logout", "javascript:alert(1)"]
      expect(subject).not_to be_valid
      expect(subject.errors[:post_logout_redirect_uris]).to be_present
    end

    it "safely rejects non-array, non-string assignments without raising" do
      subject.post_logout_redirect_uris = { "a" => "javascript:alert(1)" }
      expect { subject.valid? }.not_to raise_error
      expect(subject).not_to be_valid
    end
  end

  describe "#valid_post_logout_redirect_uri?" do
    context "when no post_logout_redirect_uris are registered" do
      it "returns false for any URI" do
        expect(subject.valid_post_logout_redirect_uri?("https://example.com/logout")).to be false
      end

      it "returns false for blank URI" do
        expect(subject.valid_post_logout_redirect_uri?("")).to be false
        expect(subject.valid_post_logout_redirect_uri?(nil)).to be false
      end
    end

    context "when post_logout_redirect_uris are registered" do
      before do
        subject.update!(post_logout_redirect_uris: "https://example.com/logout\nhttps://example.com/logout2")
      end

      it "returns true for a registered URI" do
        expect(subject.valid_post_logout_redirect_uri?("https://example.com/logout")).to be true
        expect(subject.valid_post_logout_redirect_uri?("https://example.com/logout2")).to be true
      end

      it "returns false for an unregistered URI" do
        expect(subject.valid_post_logout_redirect_uri?("https://example.com/other")).to be false
      end

      it "returns false for a blank URI" do
        expect(subject.valid_post_logout_redirect_uri?("")).to be false
        expect(subject.valid_post_logout_redirect_uri?(nil)).to be false
      end
    end
  end
end
