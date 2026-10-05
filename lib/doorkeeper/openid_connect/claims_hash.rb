# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    # The configured claims, keyed by Symbol claim name.
    #
    # This used to be an `OpenStruct`. It is a Hash now, but it still answers the
    # OpenStruct-only forms (`claims.nickname`, `claims.nickname = ...`, String keys
    # in `[]`, `[]=` and `dig`, and `delete_field`) with a deprecation warning, so
    # apps that relied on them keep working until the next major version, when this
    # becomes a plain Hash.
    class ClaimsHash < Hash
      # Emit the deprecation at most once per process; claims are read on every
      # ID Token and UserInfo response.
      @deprecation_warned = false

      class << self
        def warn_deprecation
          return if @deprecation_warned

          @deprecation_warned = true
          warn "DEPRECATION WARNING: `Doorkeeper::OpenidConnect.configuration.claims` is a Hash " \
               "keyed by Symbol claim name. Reading or writing it method-style " \
               "(`claims.nickname`), with String keys (`claims[\"nickname\"]`) or with " \
               "`delete_field` is deprecated and will stop working in the next major version. " \
               "Use `claims[:nickname]` and `claims.delete(:nickname)` instead."
        end

        # Reset the deprecation flag (test helper).
        def reset_deprecation_warning!
          @deprecation_warned = false
        end
      end

      def [](name)
        return super unless name.is_a?(String)

        self.class.warn_deprecation
        super(name.to_sym)
      end

      def []=(name, value)
        if name.is_a?(String)
          self.class.warn_deprecation
          name = name.to_sym
        end
        super
      end

      def dig(name, *rest)
        return super unless name.is_a?(String)

        self.class.warn_deprecation
        super(name.to_sym, *rest)
      end

      # Like OpenStruct#delete_field: raises NameError for an unknown claim unless given a block.
      def delete_field(name)
        self.class.warn_deprecation
        key = name.to_sym
        return delete(key) if key?(key)
        return yield if block_given?

        raise NameError.new("no field `#{key}' in #{self.class}", key)
      end

      def method_missing(method_name, *args, &block)
        name = method_name.to_s
        if name.end_with?("=") && args.size == 1 && block.nil?
          self.class.warn_deprecation
          self[name.chomp("=").to_sym] = args.first
        elsif args.empty? && block.nil?
          self.class.warn_deprecation
          fetch(method_name, nil)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        key?(method_name) || method_name.to_s.end_with?("=") || super
      end
    end
  end
end
