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

        def jws_key(*methods)
          @config.instance_variable_set('@jws_key', methods)
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

      option :jws_key,
             default: (lambda do |routes|
               warn(I18n.translate('doorkeeper.openid_connect.errors.messages.jws_key_not_configured'))
               nil
             end)
    end
  end
end