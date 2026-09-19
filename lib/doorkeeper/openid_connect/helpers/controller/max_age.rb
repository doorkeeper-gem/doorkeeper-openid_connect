# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    module Helpers
      module Controller
        # Enforces the OIDC `max_age` authorization parameter (OIDC Core 1.0
        # §3.1.2.1): when the resource owner's last authentication is older
        # than `max_age` seconds, reauthentication is required.
        module MaxAge
          # The shapes a `Time` takes once it has been serialized into the
          # session:
          #
          # * `"2026-09-05T03:59:10.270Z"` — `ActiveSupport::JSON`, which is
          #   what the JSON cookie serializer emits
          # * `"2026/09/05 03:59:10 +0000"` — the same encoder with
          #   `ActiveSupport::JSON::Encoding.use_standard_json_time_format`
          #   turned off
          # * `"2026-09-05 03:59:27 UTC"` — `JSON.generate` on a bare `Time`
          #
          # The date separator is captured and backreferenced so the two forms
          # cannot be mixed, and the zone suffix is optional so that a
          # serializer which drops it still reads as a local time.
          OIDC_SERIALIZED_AUTH_TIME = %r{
            \A
            (?<year>\d{4})(?<sep>[-/])(?<month>\d{2})\k<sep>(?<day>\d{2})  # date
            [T\ ]
            \d{2}:\d{2}:\d{2}                    # time
            (?:\.\d+)?                           # optional fractional seconds
            (?:\ ?(?:Z|UTC|[+-]\d{2}:?\d{2}))?   # optional zone
            \z
          }x

          private

          def handle_oidc_max_age_param!(owner)
            max_age = oidc_max_age_seconds
            return unless max_age && owner

            auth_time = normalized_oidc_auth_time(owner)

            # NOTE: clock skew
            max_age = [1, max_age].max

            return unless oidc_auth_time_stale?(auth_time, max_age)

            # OIDC Core 1.0 §3.1.2.1: with `prompt=none` the Authorization Server
            # MUST NOT display any authentication UI. Reauthentication required by
            # `max_age` must therefore be reported as `login_required` instead of
            # triggering the interactive `reauthenticate_resource_owner` flow.
            # (Conflicting combinations like `prompt=none login` are still left to
            # `handle_oidc_prompt_param!`, which raises `invalid_request`.)
            raise Errors::LoginRequired if oidc_prompt_values == ["none"]

            reauthenticate_oidc_resource_owner(owner)
          end

          # Parse the `max_age` request parameter into a non-negative number of
          # seconds, or nil when it is absent, malformed, or non-scalar.
          #
          # `max_age` is a single string per OIDC Core §3.1.2.1. A malformed
          # request can supply an Array (`max_age[]=1`) or a hash-like
          # ActionController::Parameters (`max_age[a]=1`), which does not
          # respond to `to_i` — such values are ignored rather than raising a
          # 500.
          def oidc_max_age_seconds
            raw_max_age = params[:max_age]
            return unless raw_max_age.is_a?(String) || raw_max_age.is_a?(Integer)

            max_age = raw_max_age.to_i
            return unless raw_max_age.to_s == "0" || max_age > 0

            max_age
          end

          # Normalize non-Time values (e.g. an Integer epoch) so that the
          # staleness subtraction yields a Float of elapsed seconds rather
          # than a shifted Time value.
          def normalized_oidc_auth_time(owner)
            auth_time = resolve_oidc_auth_time(owner)
            return auth_time if !auth_time || auth_time.is_a?(Time) || auth_time.is_a?(DateTime)
            return parse_oidc_auth_time_string(auth_time) if auth_time.is_a?(String)

            Time.zone.at(auth_time.to_i)
          end

          # A `Time` written to the session comes back as a String once the
          # session is serialized, which is the default since Rails 7.0
          # (`config.load_defaults` selects the JSON cookie serializer). Running
          # such a value through `to_i` yields the leading year — `"2026-09-05
          # T03:59:10.270Z".to_i` is `2026` — placing auth_time in 1970 and
          # making every `max_age` request look stale, so the RP and the
          # provider bounce the user through reauthentication forever. Same
          # class of bug as #248, which fixed the Integer case.
          #
          # A numeric String is an epoch. The grammar covers every *numeric*
          # String `to_i` resolved — optional surrounding whitespace, an
          # optional sign, an optional fractional part — and `to_f` rather than
          # `to_i` keeps the sub-second part of `"1757150000.5"`. A signed
          # value stays meaningful either way: `"+1757150000"` is the epoch it
          # looks like, and a negative one resolves to a pre-1970 time, which
          # is stale under any `max_age` and so requires reauthentication
          # regardless.
          #
          # Anchoring it at both ends is the one deliberate narrowing here.
          # `to_i` also truncated a String to its leading integer, so
          # `"1788703912 seconds"` used to resolve and no longer does. Keeping
          # that as a fallback would reinstate the bug above for every
          # serialization this method does not recognise —
          # `"20260905T035910Z".to_i` is `20260905`, i.e. 1970 and stale
          # forever — while reading `"99999999999999 garbage"` as a year
          # 3170843 timestamp, i.e. fresh. Truncation guesses wrong in both
          # directions; a String that is not wholly a number is not an epoch.
          #
          # Anything else has to look like one of the
          # serialized timestamps, which `Time.zone.parse` then reads. `parse`
          # is not used on its own because it is far more permissive than any
          # of those formats: it takes `"10 minutes"` for day 10 of the current
          # month, and such a value landing in the future would read as *fresh*
          # and silently skip the `max_age` reauthentication.
          # `Time.zone.iso8601` is no alternative — it rejects the bare-`Time`
          # form outright.
          #
          # Matching the shape is not enough on its own: `parse` rolls an
          # impossible calendar date over instead of raising, so `"2026-02-31"`
          # comes back as 2026-03-03 — a date far enough ahead would read as
          # fresh and skip the reauthentication. The day is therefore checked
          # with `Date.valid_date?` before parsing.
          #
          # What is left over is rescued: an out-of-range hour, minute or
          # second raises `ArgumentError`, and a numeric String too long to be
          # a Float (`"9" * 400` overflows to `Float::INFINITY`) makes
          # `Time.zone.at` raise `FloatDomainError`. A value of any of these
          # shapes returns nil, which `oidc_auth_time_stale?` treats as "no
          # known auth_time" and so requires reauthentication — a malformed
          # callback value must fail closed, not 500.
          def parse_oidc_auth_time_string(value)
            return Time.zone.at(value.to_f) if value.match?(/\A\s*[+-]?\d+(?:\.\d+)?\s*\z/)

            match = OIDC_SERIALIZED_AUTH_TIME.match(value)
            return unless match
            return unless Date.valid_date?(match[:year].to_i, match[:month].to_i, match[:day].to_i)

            Time.zone.parse(value)
          rescue ArgumentError, RangeError
            nil
          end

          def oidc_auth_time_stale?(auth_time, max_age)
            !auth_time || (Time.zone.now - auth_time) > max_age
          end

          # Resolve auth_time for max_age enforcement.
          #
          # Prefers `auth_time_from_session` so that multi-session deployments can
          # return the auth_time of the *current* session rather than the user's
          # most recent login on any device (issue #150). Falls back to the legacy
          # `auth_time_from_resource_owner` with a one-time deprecation warning.
          def resolve_oidc_auth_time(owner)
            config = Doorkeeper::OpenidConnect.configuration

            if config.auth_time_from_session
              return instance_exec(session, request, &config.auth_time_from_session)
            end

            Doorkeeper::OpenidConnect::Helpers::Controller.warn_auth_time_from_resource_owner_deprecation
            instance_exec(owner, &config.auth_time_from_resource_owner)
          end
        end
      end
    end
  end
end
