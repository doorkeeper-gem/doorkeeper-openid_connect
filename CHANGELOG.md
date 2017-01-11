### Unreleased

#### Changes

* The configuration setting `jws_public_key` wasn't actually used, it's deprecated now and will be removed in the next major release
* nil values and empty strings are now removed from the UserInfo and IdToken responses
* Claims now receive an optional second `scopes` argument which allow you to dynamically adjust claim values based on the requesting applications' scopes
* The configuration setting `protocol` was added.

<a name="v1.1.0"></a>
### v1.1.0 (2016-11-30)

This release is a general clean-up and adds support for some advanced OpenID Connect features.

#### Upgrading

- This version adds a table to store temporary nonces, use the generator `doorkeeper:openid_connect:migration` to create a migration
- Implement the new configuration callbacks `auth_time_from_resource_owner` and `reauthenticate_resource_owner` to support advanced features

#### Features

* Add discovery endpoint	 ([a16caa8](/../../commit/a16caa8))
* Add webfinger and keys endpoints for discovery	 ([f70898b](/../../commit/f70898b))
* Add supported claims to discovery response	 ([1d8f9ea](/../../commit/1d8f9ea))
* Support prompt=none parameter	 ([c775d8b](/../../commit/c775d8b))
* Store and return nonces in IdToken responses	 ([d28ca8c](/../../commit/d28ca8c))
* Add generator for initializer	 ([80399fd](/../../commit/80399fd))
* Support max_age parameter	 ([aabe3aa](/../../commit/aabe3aa))
* Respect scope grants in UserInfo response	 ([25f2170](/../../commit/25f2170))
