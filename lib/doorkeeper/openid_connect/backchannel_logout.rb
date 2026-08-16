# frozen_string_literal: true

require "net/http"
require "uri"

module Doorkeeper
  module OpenidConnect
    # Delivers OpenID Connect Back-Channel Logout 1.0 Logout Tokens (§2.5):
    # for each relevant client a signed LogoutToken is POSTed to the client's
    # registered `backchannel_logout_uri` as
    # `application/x-www-form-urlencoded` with a single `logout_token`
    # parameter.
    #
    # The gem tracks no OP-side sessions, so it cannot know when one ends —
    # the host application calls this from its own session-teardown path
    # (e.g. a Devise `after_sign_out_path_for` override or `Warden::Manager
    # .after_logout` hook):
    #
    #   Doorkeeper::OpenidConnect::BackchannelLogout.notify(user)
    #
    # Which clients are notified: every application with a registered
    # `backchannel_logout_uri` that has ever been issued an access token or
    # grant for this resource owner. The OP cannot observe RP sessions, so
    # this deliberately over-approximates "RP sessions associated with the
    # End-User" (§2.5) — a superfluous logout notification is harmless while
    # a missed one leaves an RP session alive. Pass `applications:` to
    # override the set.
    #
    # Delivery is sequential and best-effort: §2.8 tells the OP not to treat
    # RP errors as fatal, so one client's failure never prevents notifying
    # the rest. Each delivery yields a Result; failures additionally log a
    # warning. Redirect responses are not followed (Net::HTTP does not
    # follow them), which keeps the POST from being replayed at locations
    # the client never registered.
    module BackchannelLogout
      # The outcome of one delivery attempt. `status` is the HTTP status
      # (§2.8: 200 marks success, 400 a rejected Logout Token) unless the
      # request itself failed, in which case `error` carries the exception.
      Result = Struct.new(:application, :uri, :status, :error, keyword_init: true) do
        def delivered?
          error.nil? && status.is_a?(Integer) && (200..299).cover?(status)
        end
      end

      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 5

      module_function

      # Notifies every relevant client that the End-User's session ended.
      #
      # @param resource_owner [Object] the logged-out user, as expected by the
      #   configured `subject` block
      # @param applications [Enumerable, nil] the clients to notify; defaults
      #   to every application with a `backchannel_logout_uri` that has been
      #   issued a token or grant for this user. Entries without a logout URI
      #   are skipped.
      #
      # @return [Array<Result>] one entry per attempted delivery
      def notify(resource_owner, applications: nil)
        applications ||= applications_for(resource_owner)

        applications.filter_map do |application|
          next if application.backchannel_logout_uri.blank?

          deliver(resource_owner, application)
        end
      end

      # Delivers a single Logout Token to one client. Any failure — building
      # the token, resolving the URI, or the HTTP round trip — is captured in
      # the Result (and logged) instead of raised, so `notify` can proceed
      # with the remaining clients.
      #
      # @return [Result]
      def deliver(resource_owner, application)
        uri = URI.parse(application.backchannel_logout_uri)
        token = LogoutToken.new(resource_owner, application).as_jws_token

        response = post_logout_token(uri, token)
        Result.new(application: application, uri: uri.to_s, status: response.code.to_i)
      rescue StandardError => e
        ::Rails.logger.warn(
          "[DOORKEEPER-OPENID_CONNECT] Back-channel logout delivery to " \
            "#{application.backchannel_logout_uri.inspect} (client #{application.uid}) " \
            "failed: #{e.class}: #{e.message}",
        )
        Result.new(application: application, uri: application.backchannel_logout_uri, error: e)
      end

      # The applications to notify for this resource owner: a registered
      # `backchannel_logout_uri` plus at least one access token or grant
      # issued to the user. Revoked and expired tokens count — an RP session
      # typically outlives the tokens that established it.
      def applications_for(resource_owner)
        application_model = ::Doorkeeper.config.application_model
        unless application_model.column_names.include?("backchannel_logout_uri")
          return application_model.none
        end

        config = ::Doorkeeper.config
        application_ids =
          owner_scope(config.access_token_model, resource_owner).distinct.pluck(:application_id) |
          owner_scope(config.access_grant_model, resource_owner).distinct.pluck(:application_id)

        application_model
          .where.not(backchannel_logout_uri: [nil, ""])
          .where(id: application_ids.compact)
      end

      def owner_scope(model, resource_owner)
        if ::Doorkeeper.config.try(:polymorphic_resource_owner?)
          model.where(resource_owner: resource_owner)
        else
          model.where(resource_owner_id: resource_owner.id)
        end
      end
      private_class_method :owner_scope

      def post_logout_token(uri, token)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT

        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data("logout_token" => token)

        http.start { |session| session.request(request) }
      end
      private_class_method :post_logout_token
    end
  end
end
