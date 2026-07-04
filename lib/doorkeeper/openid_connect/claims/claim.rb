# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Claims
      class Claim
        attr_accessor :name, :response
        attr_reader :scopes

        # http://openid.net/specs/openid-connect-core-1_0.html#StandardClaims
        # http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims
        STANDARD_CLAIMS = {
          profile: %i[
            name family_name given_name middle_name nickname preferred_username
            profile picture website gender birthdate zoneinfo locale updated_at
          ],
          email: %i[email email_verified],
          address: %i[address],
          phone: %i[phone_number phone_number_verified],
        }.freeze

        def initialize(options = {})
          @name = options[:name].to_sym
          # Symbolize so a claim configured with string responses
          # (`response: ["id_token"]`) matches the symbol tokens the builder
          # dispatches with (`:id_token` / `:user_info`); otherwise such a
          # claim would be silently dropped from every response.
          @response = Array.wrap(options[:response]).compact.map(&:to_sym).freeze
          @scopes = normalize_scopes(options[:scope])

          # use default scope for Standard Claims, fallback to profile
          @scopes = [default_scope].freeze if @scopes.empty?
        end

        def scope
          @scopes.first
        end

        private

        def normalize_scopes(value)
          Array.wrap(value).compact.map(&:to_sym).freeze
        end

        def default_scope
          STANDARD_CLAIMS.find do |_scope, claims|
            claims.include? @name
          end.try(:first) || :profile
        end
      end
    end
  end
end
