# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    def self.configure(&block)
      if Doorkeeper.configuration.orm != :active_record
        raise Errors::InvalidConfiguration, 'Doorkeeper OpenID Connect currently only supports the ActiveRecord ORM adapter'
      end

      @config = Config::Builder.new(&block).build
    end

    def self.configuration
      @config || (raise Errors::MissingConfiguration)
    end

    class Config
      class Builder
        def initialize(&block)
          @config = Config.new
          instance_eval(&block)
        end

        def build
          @config
        end

        def jws_public_key(*_args)
          puts 'DEPRECATION WARNING: `jws_public_key` is not needed anymore and will be removed in a future version, please remove it from config/initializers/doorkeeper_openid_connect.rb'
        end

        def jws_private_key(*args)
          puts 'DEPRECATION WARNING: `jws_private_key` has been replaced by `signing_key` and will be removed in a future version, please remove it from config/initializers/doorkeeper_openid_connect.rb'
          signing_key(*args)
        end
      end

      module Option
        # Defines configuration option
        #
        # When you call option, it defines two methods. One method will take place
        # in the +Config+ class and the other method will take place in the
        # +Builder+ class.
        #
        # The +name+ parameter will set both builder method and config attribute.
        # If the +:as+ option is defined, the builder method will be the specified
        # option while the config attribute will be the +name+ parameter.
        #
        # If you want to introduce another level of config DSL you can
        # define +builder_class+ parameter.
        # Builder should take a block as the initializer parameter and respond to function +build+
        # that returns the value of the config attribute.
        #
        # ==== Options
        #
        # * [:+as+] Set the builder method that goes inside +configure+ block
        # * [+:default+] The default value in case no option was set
        #
        # ==== Examples
        #
        #    option :name
        #    option :name, as: :set_name
        #    option :name, default: 'My Name'
        #    option :scopes builder_class: ScopesBuilder
        #
        def option(name, options = {})
          attribute = options[:as] || name
          attribute_builder = options[:builder_class]

          Builder.instance_eval do
            define_method name do |*args, &block|
              # TODO: is builder_class option being used?
              value = if attribute_builder
                        attribute_builder.new(&block).build
                      else
                        block || args.first
                      end

              @config.instance_variable_set(:"@#{attribute}", value)
            end
          end

          define_method attribute do |*_|
            if instance_variable_defined?(:"@#{attribute}")
              instance_variable_get(:"@#{attribute}")
            else
              options[:default]
            end
          end

          public attribute
        end

        def extended(base)
          base.send(:private, :option)
        end
      end

      extend Option

      option :issuer
      option :signing_key
      option :signing_algorithm, default: :rs256
      option :subject_types_supported, default: [:public]

      option :resource_owner_from_access_token, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate('doorkeeper.openid_connect.errors.messages.resource_owner_from_access_token_not_configured')
      }

      option :auth_time_from_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate('doorkeeper.openid_connect.errors.messages.auth_time_from_resource_owner_not_configured')
      }

      option :reauthenticate_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate('doorkeeper.openid_connect.errors.messages.reauthenticate_resource_owner_not_configured')
      }

      option :select_account_for_resource_owner, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate('doorkeeper.openid_connect.errors.messages.select_account_for_resource_owner_not_configured')
      }

      option :subject, default: lambda { |*_|
        raise Errors::InvalidConfiguration, I18n.translate('doorkeeper.openid_connect.errors.messages.subject_not_configured')
      }

      option :expiration, default: 120

      option :claims, builder_class: ClaimsBuilder

      option :protocol, default: lambda { |*_|
        ::Rails.env.production? ? :https : :http
      }

      option :end_session_endpoint, default: lambda { |*_|
        nil
      }
    end
  end
end
