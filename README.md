# Doorkeeper::OpenidConnect

[![Build Status](https://travis-ci.org/doorkeeper-gem/doorkeeper-openid_connect.svg?branch=master)](https://travis-ci.org/doorkeeper-gem/doorkeeper-openid_connect)
[![Dependency Status](https://gemnasium.com/doorkeeper-gem/doorkeeper-openid_connect.svg?travis)](https://gemnasium.com/doorkeeper-gem/doorkeeper-openid_connect)
[![Code Climate](https://codeclimate.com/github/doorkeeper-gem/doorkeeper-openid_connect.svg)](https://codeclimate.com/github/doorkeeper-gem/doorkeeper-openid_connect)
[![Gem Version](https://badge.fury.io/rb/doorkeeper-openid_connect.svg)](https://rubygems.org/gems/doorkeeper-openid_connect)

This library implements an [OpenID Connect](http://openid.net/connect/) authentication provider for Rails applications on top of the [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) OAuth 2.0 framework.

OpenID Connect is a single-sign-on and identity layer with a [growing list of server and client implementations](http://openid.net/developers/libraries/). If you're looking for a client in Ruby check out [omniauth-openid-connect](https://github.com/jjbohn/omniauth-openid-connect/).

## Table of Contents

- [Status](#status)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Scopes](#scopes)
  - [Claims](#claims)
  - [Routes](#routes)
  - [Nonces](#nonces)
  - [Internationalization (I18n)](#internationalization-i18n)
- [Development](#development)
- [License](#license)
- [Sponsors](#sponsors)

## Status

The following parts of [OpenID Connect Core 1.0](http://openid.net/specs/openid-connect-core-1_0.html) are currently supported:
- [Authentication using the Authorization Code Flow](http://openid.net/specs/openid-connect-core-1_0.html#CodeFlowAuth)
- [Requesting Claims using Scope Values](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims)
- [UserInfo Endpoint](http://openid.net/specs/openid-connect-core-1_0.html#UserInfo)
- [Normal Claims](http://openid.net/specs/openid-connect-core-1_0.html#NormalClaims)

In addition we also support most of [OpenID Connect Discovery 1.0](http://openid.net/specs/openid-connect-discovery-1_0.html) for automatic configuration discovery.

Take a look at the [DiscoveryController](app/controllers/doorkeeper/openid_connect/discovery_controller.rb) for more details on supported features.

## Installation

Make sure your application is already set up with [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper#installation).

Add this line to your application's `Gemfile` and run `bundle install`:

```ruby
gem 'doorkeeper-openid_connect'
```

Run the installation generator to update routes and create the initializer:

```sh
rails generate doorkeeper:openid_connect:install
```

Generate a migration for Active Record (other ORMs are currently not supported):

```sh
rails generate doorkeeper:openid_connect:migration
rake db:migrate
```

If you're upgrading from an earlier version, check [CHANGELOG.md](CHANGELOG.md) for upgrade instructions.

## Configuration

Make sure you've [configured Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper#configuration) before continuing.

Verify your settings in `config/initializers/doorkeeper.rb`:

- `resource_owner_authenticator`
  - This callback needs to returns a falsey value if the current user can't be determined:

    ```ruby
    resource_owner_authenticator do
      if current_user
        current_user
      else
        redirect_to(new_user_session_url)
        nil
      end
    end
    ```

The following settings are required in `config/initializers/doorkeeper_openid_connect.rb`:

- `issuer`
  - Identifier for the issuer of the response (i.e. your application URL). The value is a case sensitive URL using the `https` scheme that contains scheme, host, and optionally, port number and path components and no query or fragment components.
- `subject`
  - Identifier for the resource owner (i.e. the authenticated user). A locally unique and never reassigned identifier within the issuer for the end-user, which is intended to be consumed by the client. The value is a case-sensitive string and must not exceed 255 ASCII characters in length.
  - The database ID of the user is an acceptable choice if you don't mind leaking that information.
- `jws_private_key`
  - Private RSA key for [JSON Web Signature](https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31).
  - You can generate a private key with the `openssl` command, see e.g. [Generate a keypair using OpenSSL](https://en.wikibooks.org/wiki/Cryptography/Generate_a_keypair_using_OpenSSL).
  - You should not commit the key to your repository, but use an external file (in combination with `File.read`) and/or the [dotenv-rails](https://github.com/bkeepers/dotenv) gem (in combination with `ENV[...]`).
- `resource_owner_from_access_token`
  - Defines how to translate the Doorkeeper access token to a resource owner model.

The following settings are optional, but recommended for better client compatibility:

- `auth_time_from_resource_owner`
  - Returns the time of the user's last login, this can be a `Time`, `DateTime`, or any other class that responds to `to_i`
  - Required to support the `max_age` parameter and the `auth_time` claim.
- `reauthenticate_resource_owner`
  - Defines how to trigger reauthentication for the current user (e.g. display a password prompt, or sign-out the user and redirect to the login form).
  - Required to support the `max_age` and `prompt=login` parameters.

The following settings are optional:

- `expiration`
  - Expiration time after which the ID Token must not be accepted for processing by clients.
  - The default is 120 seconds

### Scopes

To perform authentication over OpenID Connect, an OAuth client needs to request the `openid` scope. This scope needs to be enabled using either `optional_scopes` in the global Doorkeeper configuration in `config/initializers/doorkeeper.rb`, or by adding it to any OAuth application's `scope` attribute.

> Note that any application defining its own scopes won't inherit the scopes defined in the initializer, so you might have to update existing applications as well.
>
> See [Using Scopes](https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes) in the Doorkeeper wiki for more information.

### Claims

Claims can be defined in a `claims` block inside `config/initializers/doorkeeper_openid_connect.rb`:

```ruby
Doorkeeper::OpenidConnect.configure do
  claims do
    claim :email do |resource_owner|
      resource_owner.email
    end

    claim :full_name do |resource_owner|
      "#{resource_owner.first_name} #{resource_owner.last_name}"
    end
  end
end
```

You can pass a `scope:` keyword argument on each claim to specify which OAuth scope should be required to access the claim. If you define any of the defined [Standard Claims](http://openid.net/specs/openid-connect-core-1_0.html#StandardClaims) they will by default use their [corresponding scopes](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims) (`profile`, `email`, `address` and `phone`), and any other claims will by default use the `profile` scope. Again, to use any of these scopes you need to enable them as described above.

### Routes

The installation generator will update your `config/routes.rb` to define all required routes:

``` ruby
Rails.application.routes.draw do
  use_doorkeeper_openid_connect
  # your routes
end
```

This will mount the following routes:

```
GET   /oauth/userinfo
POST  /oauth/userinfo
GET   /oauth/discovery/keys
GET   /.well-known/openid-configuration
GET   /.well-known/webfinger
```

With the exception of the hard-coded `/.well-known` paths (see [RFC 5785](https://tools.ietf.org/html/rfc5785)) you can customize routes in the same way as with Doorkeeper, please refer to [this page on their wiki](https://github.com/doorkeeper-gem/doorkeeper/wiki/Customizing-routes#version--05-1).

### Nonces

To support clients who send nonces you have to tweak Doorkeeper's authorization view so the parameter is passed on.

If you don't already have custom templates, run this generator in your Rails application to add them:

```sh
rails generate doorkeeper:views
```

Then tweak the template as follows:

```patch
--- i/app/views/doorkeeper/authorizations/new.html.erb
+++ w/app/views/doorkeeper/authorizations/new.html.erb
@@ -26,6 +26,7 @@
       <%= hidden_field_tag :state, @pre_auth.state %>
       <%= hidden_field_tag :response_type, @pre_auth.response_type %>
       <%= hidden_field_tag :scope, @pre_auth.scope %>
+      <%= hidden_field_tag :nonce, @pre_auth.nonce %>
       <%= submit_tag t('doorkeeper.authorizations.buttons.authorize'), class: "btn btn-success btn-lg btn-block" %>
     <% end %>
     <%= form_tag oauth_authorization_path, method: :delete do %>
@@ -34,6 +35,7 @@
       <%= hidden_field_tag :state, @pre_auth.state %>
       <%= hidden_field_tag :response_type, @pre_auth.response_type %>
       <%= hidden_field_tag :scope, @pre_auth.scope %>
+      <%= hidden_field_tag :nonce, @pre_auth.nonce %>
       <%= submit_tag t('doorkeeper.authorizations.buttons.deny'), class: "btn btn-danger btn-lg btn-block" %>
     <% end %>
   </div>
```

### Internationalization (I18n)

We use Rails locale files for error messages and scope descriptions, see [config/locales/en.yml](config/locales/en.yml). You can override these by adding them to your own translations in `config/locale`.

## Development

Run `bundle install` to setup all development dependencies.

To run all specs:

```sh
bundle exec rspec
```

To run the local engine server:

```sh
cd spec/dummy
bundle exec rails server
```

By default, the latest Rails version is used. To use a specific version run:

```
rails=4.2.0 bundle update
```

## License

Doorkeeper::OpenidConnect is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Sponsors

Initial development of this project was sponsored by [PlayOn! Sports](https://github.com/playon).
