## Unreleased

No changes yet.

## v1.5.1 (2018-09-04)

### Changes

- This gem is now compatible with Doorkeeper 5.x

## v1.5.0 (2018-06-27)

### Features

- Custom claims can now also be returned directly in the ID token, see the updated README for usage instructions

## v1.4.0 (2018-05-31)

### Upgrading

- Support for Ruby versions older than 2.3 was dropped

### Features

- Redirect errors per Section 3.1.2.6 of OpenID Connect 1.0 (by @ryands)
- Set `id_token` when it's nil in token response (it's used in `refresh_token` requests) (by @Miouge1)

## v1.3.0 (2018-03-05)

### Features

- Support for Implicit Flow (`response_type=id_token` and `response_type=id_token token`),
  see the updated README for usage instructions (by @nashby, @nhance and @stevenvegt)

## v1.2.0 (2017-08-31)

### Upgrading

- The configuration setting `jws_private_key` was renamed to `signing_key`, you can still use the old name until it's removed in the next major release

### Features

- Support for pairwise subject identifiers (by @travisofthenorth)
- Support for EC and HMAC signing algorithms (by @110y)
- Claims now receive an optional third `access_token` argument which allow you to dynamically adjust claim values based on the client's token (by @gigr)

### Bugfixes

## v1.1.2 (2017-01-18)

### Bugfixes

- Fixes the `undefined local variable or method 'pre_auth'` error

## v1.1.1 (2017-01-18)

#### Upgrading

- The configuration setting `jws_public_key` wasn't actually used, it's deprecated now and will be removed in the next major release
- The undocumented shorthand `to_proc` syntax for defining claims (`claim :user, &:name`) is not supported anymore

#### Features

- Claims now receive an optional second `scopes` argument which allow you to dynamically adjust claim values based on the requesting applications' scopes (by @nbibler)
- The `prompt` parameter values `login` and `consent` are now supported
- The configuration setting `protocol` was added (by @gigr)

#### Bugfixes

- Standard Claims are now mapped correctly to their default scopes (by @tylerhunt)
- Blank `nonce` parameters are now ignored

#### Changes

- `nil` values and empty strings are now removed from the UserInfo and IdToken responses
- Allow `json-jwt` dependency at ~> 1.6. (by @nbibler)
- Configuration blocks no longer internally use `instance_eval` which previously gave undocumented and unexpected `self` access to the caller (by @nbibler)

## v1.1.0 (2016-11-30)

This release is a general clean-up and adds support for some advanced OpenID Connect features.

#### Upgrading

- This version adds a table to store temporary nonces, use the generator `doorkeeper:openid_connect:migration` to create a migration
- Implement the new configuration callbacks `auth_time_from_resource_owner` and `reauthenticate_resource_owner` to support advanced features

#### Features

- Add discovery endpoint	 ([a16caa8](/../../commit/a16caa8))
- Add webfinger and keys endpoints for discovery	 ([f70898b](/../../commit/f70898b))
- Add supported claims to discovery response	 ([1d8f9ea](/../../commit/1d8f9ea))
- Support prompt=none parameter	 ([c775d8b](/../../commit/c775d8b))
- Store and return nonces in IdToken responses	 ([d28ca8c](/../../commit/d28ca8c))
- Add generator for initializer	 ([80399fd](/../../commit/80399fd))
- Support max_age parameter	 ([aabe3aa](/../../commit/aabe3aa))
- Respect scope grants in UserInfo response	 ([25f2170](/../../commit/25f2170))
