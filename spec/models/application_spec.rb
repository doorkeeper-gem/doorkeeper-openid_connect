# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::Orm::ActiveRecord::Mixins::Application do
  subject { create(:application) }

  it 'extends the base doorkeeper Application' do
    expect(subject).to respond_to(:post_logout_redirect_uris)
    expect(subject).to respond_to(:valid_post_logout_redirect_uri?)
  end

  describe '#post_logout_redirect_uris' do
    it 'returns an empty array when not set' do
      expect(subject.post_logout_redirect_uris).to eq([])
    end

    it 'returns an array of URIs when set as a string' do
      subject.update!(post_logout_redirect_uris: "https://example.com/logout\nhttps://example.com/logout2")
      expect(subject.post_logout_redirect_uris).to eq(%w[https://example.com/logout https://example.com/logout2])
    end

    it 'accepts an array and stores URIs as newline-separated string' do
      uris = ['https://example.com/logout', 'https://example.com/logout2']
      subject.post_logout_redirect_uris = uris
      subject.save!
      subject.reload
      expect(subject.post_logout_redirect_uris).to eq(uris)
    end
  end

  describe '#valid_post_logout_redirect_uri?' do
    context 'when no post_logout_redirect_uris are registered' do
      it 'returns false for any URI' do
        expect(subject.valid_post_logout_redirect_uri?('https://example.com/logout')).to be false
      end

      it 'returns false for blank URI' do
        expect(subject.valid_post_logout_redirect_uri?('')).to be false
        expect(subject.valid_post_logout_redirect_uri?(nil)).to be false
      end
    end

    context 'when post_logout_redirect_uris are registered' do
      before do
        subject.update!(post_logout_redirect_uris: "https://example.com/logout\nhttps://example.com/logout2")
      end

      it 'returns true for a registered URI' do
        expect(subject.valid_post_logout_redirect_uri?('https://example.com/logout')).to be true
        expect(subject.valid_post_logout_redirect_uri?('https://example.com/logout2')).to be true
      end

      it 'returns false for an unregistered URI' do
        expect(subject.valid_post_logout_redirect_uri?('https://example.com/other')).to be false
      end

      it 'returns false for a blank URI' do
        expect(subject.valid_post_logout_redirect_uri?('')).to be false
        expect(subject.valid_post_logout_redirect_uri?(nil)).to be false
      end
    end
  end
end
