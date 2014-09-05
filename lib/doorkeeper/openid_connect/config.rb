module Doorkeeper
  module OpenidConnect
    class MissingConfiguration < StandardError
      def initialize
        super('Configuration for Doorkeeper OpenID Connect missing. Do you have doorkeeper_openid_connect initializer?')
      end
    end

    def self.configure(&block)
      @config = Config::Builder.new(&block).build
    end

    def self.configuration
      @config || (fail MissingConfiguration.new)
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

        def jws_private_key(jws_private_key)
          @config.instance_variable_set('@jws_private_key', jws_private_key)
        end

        def jws_public_key(jws_public_key)
          @config.instance_variable_set('@jws_public_key', jws_public_key)
        end

        def issuer(issuer)
          @config.instance_variable_set('@issuer', issuer)
        end

        def expiration(expiration)
          @config.instance_variable_set('@expiration', expiration)
        end

        def resource_owner_from_access_token(*method)
          @config.instance_variable_set('@resource_owner_from_access_token', *method)
        end

        def subject(*method)
          @config.instance_variable_set('@subject', *method)
        end

        def email(*method)
          @config.instance_variable_set('@email', *method)
        end

        def assignments(*method)
          @config.instance_variable_set('@assignments', *method)
        end

        def additional_claims(*method)
          @config.instance_variable_set('@additional_claims', *method)
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
              value = unless attribute_builder
                        block ? block : args.first
                      else
                        attribute_builder.new(&block).build
                      end

              @config.instance_variable_set(:"@#{attribute}", value)
            end
          end

          define_method attribute do |*args|
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

      option :resource_owner_from_access_token,
             default: (lambda do |access_token|
               logger.warn(I18n.translate('doorkeeper.openid_connect.errors.messages.resource_owner_from_access_token_configured'))
               nil
             end)

      option :subject,
             default: (lambda do |resource_owner|
               logger.warn(I18n.translate('doorkeeper.openid_connect.errors.messages.subject_configured'))
               nil
             end)

      option :email,
             default: (lambda do |resource_owner|
               logger.warn(I18n.translate('doorkeeper.openid_connect.errors.messages.email_configured'))
               nil
             end)

      option :assignments,
             default: (lambda do |resource_owner|
               logger.warn(I18n.translate('doorkeeper.openid_connect.errors.messages.assignments_configured'))
               nil
             end)

      option :additional_claims,
              default: (lambda do |resource_owner|
                logger.warn(I18n.translate('doorkeeper.openid_connect.errors.messages.additional_claims_configured'))
                {}
              end)

      option :jws_private_key, default: nil
      option :jws_public_key, default: nil
      option :issuer, default: nil
      option :expiration, default: 1.minute
    end
  end
end
