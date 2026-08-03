# frozen_string_literal: true

require "rails_helper"

# Several files under `lib/` exist for their side effect: they define a module
# and prepend it onto one of Doorkeeper's own classes. Nothing ever references
# those modules by name — callers reach the behavior through Doorkeeper's
# constant — so converting their `require` to an `autoload` would leave the
# prepend undone. There would be no load error to catch it, and the eager-load
# check would not catch it either, because forcing the autoload is exactly what
# makes the prepend happen in that process.
#
# Hence this: assert the extensions are in place after a plain boot. Ancestors
# are compared by name so that a missing prepend is not papered over by the
# assertion itself triggering the autoload. Position matters too: a prepended
# module sits before its target in `ancestors`, an included one after, so the
# index comparison fails if an extension ever degrades to `include`.
RSpec.describe "Doorkeeper extensions applied while the gem loads" do
  {
    "Doorkeeper::Helpers::Controller" =>
      "Doorkeeper::OpenidConnect::Helpers::Controller",
    "Doorkeeper::OAuth::Authorization::Code" =>
      "Doorkeeper::OpenidConnect::OAuth::Authorization::Code",
    "Doorkeeper::OAuth::AuthorizationCodeRequest" =>
      "Doorkeeper::OpenidConnect::OAuth::AuthorizationCodeRequest",
    "Doorkeeper::OAuth::PasswordAccessTokenRequest" =>
      "Doorkeeper::OpenidConnect::OAuth::PasswordAccessTokenRequest",
    "Doorkeeper::OAuth::PreAuthorization" =>
      "Doorkeeper::OpenidConnect::OAuth::PreAuthorization",
    "Doorkeeper::OAuth::TokenResponse" =>
      "Doorkeeper::OpenidConnect::OAuth::TokenResponse",
  }.each do |target, extension|
    it "prepends #{extension} onto #{target}" do
      ancestors = target.constantize.ancestors.map(&:to_s)

      expect(ancestors).to include(extension)
      expect(ancestors.index(extension)).to be < ancestors.index(target)
    end
  end

  # The grant flow registry stores the strategy class itself, not a name to
  # resolve later, so both strategies have to exist by the time this file
  # finishes loading. That is why they are the two requires left in Doorkeeper's
  # `Request` namespace.
  {
    id_token: "Doorkeeper::Request::IdToken",
    "id_token token": "Doorkeeper::Request::IdTokenToken",
  }.each do |flow, strategy|
    it "registers the #{flow} flow with #{strategy}" do
      registered = Doorkeeper::GrantFlow.get(flow)

      expect(registered).not_to be_nil
      expect(registered.response_type_strategy.to_s).to eq(strategy)
    end
  end

  it "prepends the openid_request association hook onto Doorkeeper's access grant mixin" do
    extension = "Doorkeeper::OpenidConnect::Orm::ActiveRecord::AccessGrantExtension"
    singleton = Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant.singleton_class
    ancestors = singleton.ancestors.map(&:to_s)

    expect(ancestors).to include(extension)
    expect(ancestors.index(extension)).to be < ancestors.index(singleton.to_s)
  end
end
