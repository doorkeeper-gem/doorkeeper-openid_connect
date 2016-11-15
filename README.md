# Doorkeeper::OpenidConnect

[![Build Status](https://travis-ci.org/doorkeeper-gem/doorkeeper-openid_connect.svg?branch=master)](https://travis-ci.org/doorkeeper-gem/doorkeeper-openid_connect)
[![Dependency Status](https://gemnasium.com/doorkeeper-gem/doorkeeper-openid_connect.svg?travis)](https://gemnasium.com/doorkeeper-gem/doorkeeper-openid_connect)
[![Code Climate](https://codeclimate.com/github/doorkeeper-gem/doorkeeper-openid_connect.svg)](https://codeclimate.com/github/doorkeeper-gem/doorkeeper-openid_connect)
[![Gem Version](https://badge.fury.io/rb/doorkeeper-openid_connect.svg)](https://rubygems.org/gems/doorkeeper-openid_connect)

This library implements [OpenID Connect](http://openid.net/connect/) for Rails applications on top of the [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) OAuth 2.0 framework.

## Table of Contents

- [Status](#status)
- [Installation](#installation)
- [Configuration](#configuration)
  - [OAuth Scopes](#oauth-scopes)
  - [Routes](#routes)
- [Development](#development)
- [License](#license)
- [Sponsors](#sponsors)

## Status

The library is usable but still a bit rough around the edges. Please refer to the [v1.0.1 README](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/blob/v1.0.1/README.md) until the next version is released.

The following parts of [OpenID Connect Core 1.0](http://openid.net/specs/openid-connect-core-1_0.html) are currently supported:
- [Authentication using the Authorization Code Flow](http://openid.net/specs/openid-connect-core-1_0.html#CodeFlowAuth)
- [Requesting Claims using Scope Values](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims)
- [UserInfo Endpoint](http://openid.net/specs/openid-connect-core-1_0.html#UserInfo)
- [Normal Claims](http://openid.net/specs/openid-connect-core-1_0.html#NormalClaims)

In addition we also support most of [OpenID Connect Discovery 1.0](http://openid.net/specs/openid-connect-discovery-1_0.html) for automatic configuration discovery.

Take a look at the [DiscoveryController](app/controllers/doorkeeper/openid_connect/discovery_controller.rb) for more details on supported features.

## Installation

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

## Configuration

Verify your settings in `config/initializers/doorkeeper.rb`:

- `resource_owner_authenticator`
  - Make sure this returns a falsey value if the current user can't be determined:
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
- `jws_private_key`, `jws_public_key`
  - Private and public RSA key pair for [JSON Web Signature](https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31).
  - You can generate these with the `openssl` command, see e.g. [Generate a keypair using OpenSSL](https://en.wikibooks.org/wiki/Cryptography/Generate_a_keypair_using_OpenSSL).
  - You should not commit these keys to your repository, but use external files (in combination with `File.read`) or the [dotenv-rails](https://github.com/bkeepers/dotenv) gem (in combination with `ENV[...]`).
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

Custom claims can optionally be specified in a `claims` block. The following claim types are currently supported:

- `normal_claim`
  - Specify claim name and a block which is called with `resource_owner` to determine the claim value.

You can pass a `scope:` keyword argument on each claim to specify which OAuth scope should be required to access the claim. [Standard Claims](http://openid.net/specs/openid-connect-core-1_0.html#StandardClaims) as defined by OpenID Connect will by default use their [corresponding scopes](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims), and any other claims will by default use the `profile` scope.

### OAuth Scopes

To authenticate using OpenID Connect, clients need to request the `openid` scope. You can either enable this for all applications using `optional_scopes` in `config/initializers/doorkeeper.rb`, or add them to any Doorkeeper application's `scope` attribute. Note that any application defining its own scopes won't inherit the scopes defined in the initializer.

The specification also defines the optional scopes `profile`, `email`, `address` and `phone` to grant access to groups of Standard Claims, as mentioned above.

See [Using Scopes](https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes) in the Doorkeeper wiki for more information.

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
