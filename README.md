# Doorkeeper::OpenidConnect

[![CI](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/actions/workflows/ci.yml/badge.svg)](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/actions/workflows/ci.yml)
[![Maintainability](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper-openid_connect/maintainability.svg)](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper-openid_connect)
[![Gem Version](https://badge.fury.io/rb/doorkeeper-openid_connect.svg)](https://rubygems.org/gems/doorkeeper-openid_connect)

This library implements an [OpenID Connect](http://openid.net/connect/) authentication provider for Rails applications on top of the [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) OAuth 2.0 framework.

OpenID Connect is a single-sign-on and identity layer with a [growing list of server and client implementations](http://openid.net/developers/libraries/). If you're looking for a client in Ruby check out [omniauth_openid_connect](https://github.com/m0n9oose/omniauth_openid_connect/).

## Table of Contents

- [Status](#status)
  - [Known Issues](#known-issues)
  - [Example Applications](#example-applications)
- [Installation](#installation)
- [Configuration](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Configuration)
- [Development](#development)
- [License](#license)
- [Sponsors](#sponsors)

## Status

The following parts of [OpenID Connect Core 1.0](http://openid.net/specs/openid-connect-core-1_0.html) are currently supported:
- [Authentication using the Authorization Code Flow](http://openid.net/specs/openid-connect-core-1_0.html#CodeFlowAuth)
- [Authentication using the Implicit Flow](http://openid.net/specs/openid-connect-core-1_0.html#ImplicitFlowAuth)
- [Requesting Claims using Scope Values](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims)
- [UserInfo Endpoint](http://openid.net/specs/openid-connect-core-1_0.html#UserInfo)
- [Normal Claims](http://openid.net/specs/openid-connect-core-1_0.html#NormalClaims)
- [OAuth 2.0 Form Post Response Mode](https://openid.net/specs/oauth-v2-form-post-response-mode-1_0.html)
- [OAuth 2.0 Dynamic Client Registration Protocol](https://datatracker.ietf.org/doc/html/rfc7591)

In addition, we also support most of [OpenID Connect Discovery 1.0](http://openid.net/specs/openid-connect-discovery-1_0.html) for automatic configuration discovery.

Take a look at the [DiscoveryController](app/controllers/doorkeeper/openid_connect/discovery_controller.rb) for more details on supported features.

### Known Issues

- Doorkeeper's API mode (`Doorkeeper.configuration.api_only`) is not properly supported yet

### Example Applications

- [GitLab](https://gitlab.com/gitlab-org/gitlab-ce) ([original MR](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/8018))
- [Testing app for this gem](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/tree/master/spec/dummy)

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

If you're upgrading from an earlier version, check [Migration from Old Versions](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Migration-from-Old-Versions)
wiki and [CHANGELOG.md](CHANGELOG.md) for upgrade instructions.

If you are upgrading an existing installation and want to use per-client
post-logout redirect URIs (RP-Initiated Logout), add the new column with:

```sh
rails generate doorkeeper:openid_connect:add_post_logout_redirect_uris
rake db:migrate
```

New installations already include this column via the migration above.

## Configuration

See the [wiki](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Configuration) for detailed configuration instructions, including:

- [Scopes](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Scopes)
- [Claims](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Claims)
- [Routes](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Routes)
- [Nonces](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Nonces)
- [Internationalization (I18n)](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/I18n)
- [Dynamic Client Registration](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Dynamic-Client-Registration)

## Development

Run `bundle install` to setup all development dependencies.

To run all specs:

```sh
bundle exec rake spec
```

To generate and run migrations in the test application:

```sh
bundle exec rake migrate
```

To run the local engine server:

```sh
bundle exec rake server
```

By default, the latest Rails version is used. To use a specific version run:

```
rails=7.2 bundle update
```

## License

Doorkeeper::OpenidConnect is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Sponsors

Initial development of this project was sponsored by [PlayOn! Sports](https://github.com/playon).
