# Doorkeeper::OpenidConnect

[![CI](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/actions/workflows/ci.yml/badge.svg)](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/actions/workflows/ci.yml)
[![Maintainability](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper-openid_connect/maintainability.svg)](https://qlty.sh/gh/doorkeeper-gem/projects/doorkeeper-openid_connect)
[![Gem Version](https://badge.fury.io/rb/doorkeeper-openid_connect.svg)](https://rubygems.org/gems/doorkeeper-openid_connect)
[![Downloads](https://img.shields.io/gem/dt/doorkeeper-openid_connect.svg)](https://rubygems.org/gems/doorkeeper-openid_connect)

This library implements an [OpenID Connect](http://openid.net/connect/) authentication provider for Rails applications on top of the [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) OAuth 2.0 framework.

OpenID Connect is a single-sign-on and identity layer with a [growing list of server and client implementations](http://openid.net/developers/libraries/). If you're looking for a client in Ruby check out [omniauth_openid_connect](https://github.com/m0n9oose/omniauth_openid_connect/).

Full documentation lives in the [wiki](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki).

## Table of Contents

- [Status](#status)
  - [Example Applications](#example-applications)
- [Requirements](#requirements)
- [Installation](#installation)
- [Documentation](#documentation)
- [Development](#development)
- [License](#license)
- [Sponsors](#sponsors)

## Status

The following parts of [OpenID Connect Core 1.0](http://openid.net/specs/openid-connect-core-1_0.html) and related specifications are currently supported:
- [Authentication using the Authorization Code Flow](http://openid.net/specs/openid-connect-core-1_0.html#CodeFlowAuth)
- [Authentication using the Implicit Flow](http://openid.net/specs/openid-connect-core-1_0.html#ImplicitFlowAuth)
- [Requesting Claims using Scope Values](http://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims)
- [UserInfo Endpoint](http://openid.net/specs/openid-connect-core-1_0.html#UserInfo)
- [Normal Claims](http://openid.net/specs/openid-connect-core-1_0.html#NormalClaims)
- [OAuth 2.0 Form Post Response Mode](https://openid.net/specs/oauth-v2-form-post-response-mode-1_0.html)
- [OAuth 2.0 Dynamic Client Registration Protocol](https://datatracker.ietf.org/doc/html/rfc7591)
- [RP-Initiated Logout 1.0](https://openid.net/specs/openid-connect-rpinitiated-1_0.html) client metadata — per-client `post_logout_redirect_uris` registration and validation; see [RP-Initiated Logout](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/RP-Initiated-Logout) for the host application's part
- [RFC 9207](https://www.rfc-editor.org/rfc/rfc9207) `iss` authorization response parameter, emitted when Doorkeeper itself is configured with an `issuer`
- [RFC 8414 Authorization Server Metadata](https://www.rfc-editor.org/rfc/rfc8414) — see [Routes](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Routes) for how this interacts with the metadata endpoint Doorkeeper 6.0 serves itself

In addition, we also support most of [OpenID Connect Discovery 1.0](http://openid.net/specs/openid-connect-discovery-1_0.html) for automatic configuration discovery.

Take a look at the [DiscoveryController](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/blob/master/app/controllers/doorkeeper/openid_connect/discovery_controller.rb) for more details on supported features.

### Example Applications

- [GitLab](https://gitlab.com/gitlab-org/gitlab) ([original MR](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/8018))
- [Testing app for this gem](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/tree/master/spec/dummy)

## Requirements

| Dependency | Supported versions |
| --- | --- |
| Ruby | 3.2 or newer |
| Rails | 7.0 to 8.1 |
| Doorkeeper | 5.5 or newer, below 7.0 |
| ORM | Active Record only |

The [CI matrix](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/blob/master/.github/workflows/ci.yml) is the authoritative statement of what is tested: each Rails series above against Ruby 3.2 through 4.0 and — except for Rails 7.0 — against `ruby-head`, plus one build per supported Doorkeeper series and one against Doorkeeper's `main` branch.

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
rails db:migrate
```

If you're upgrading from an earlier version, check [Migration from Old Versions](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Migration-from-Old-Versions)
wiki and [CHANGELOG.md](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/blob/master/CHANGELOG.md) for upgrade instructions, including the
migrations that newer versions add to existing installations.

## Documentation

Configuration and usage are documented in the [wiki](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki), whose home page indexes every topic. The pages to start from:

- [Configuration](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Configuration) — the issuer, subject, signing keys, and every other initializer option
- [Migration from Old Versions](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Migration-from-Old-Versions) — upgrade instructions for breaking changes
- [Troubleshooting](https://github.com/doorkeeper-gem/doorkeeper-openid_connect/wiki/Troubleshooting) — symptoms, causes, and fixes for common integration pitfalls

The remaining pages cover scopes and claims, `prompt` and `max_age`, routes and multiple mounts, nonces, RP-Initiated Logout, Dynamic Client Registration, and I18n.

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

By default, Rails 8.0 is used. To use a specific version run:

```sh
rails=7.2 bundle update
```

## License

Doorkeeper::OpenidConnect is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Sponsors

Initial development of this project was sponsored by [PlayOn! Sports](https://github.com/playon).
