# frozen_string_literal: true

module Doorkeeper
  module OpenidConnect
    class ResponseMode
      attr_reader :type

      def initialize(response_type)
        @type = response_type
      end

      def fragment?
        mode == 'fragment'
      end

      def query?
        mode == 'query'
      end

      def mode
        case type
        when 'token', 'id_token', 'id_token token'
          'fragment'
        else
          'query'
        end
      end
    end
  end
end
