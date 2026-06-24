# frozen_string_literal: true

require "doorkeeper/openid_connect/orm/active_record/mixins/openid_request"

module Doorkeeper
  module OpenidConnect
    class Request < ::ActiveRecord::Base
      include Orm::ActiveRecord::Mixins::OpenidRequest
    end
  end
end
