<a name="v1.1.0"></a>
### v1.1.0 (2016-11-30)

This release is a general clean-up and adds support for some advanced OpenID Connect features.
Make sure to check the updated [README.md](README.md), especially the [configuration](README.md#configuration) section.

#### Features

* Respect scope grants in UserInfo response	 ([25f2170](/../../commit/25f2170))
* Support max_age parameter	 ([aabe3aa](/../../commit/aabe3aa))
* Add generator for initializer	 ([80399fd](/../../commit/80399fd))
* Store and return nonces in IdToken responses	 ([d28ca8c](/../../commit/d28ca8c))
* Support prompt=none parameter	 ([c775d8b](/../../commit/c775d8b))
* Add supported claims to discovery response	 ([1d8f9ea](/../../commit/1d8f9ea))
* Add webfinger and keys endpoints for discovery	 ([f70898b](/../../commit/f70898b))
* Add discovery endpoint	 ([a16caa8](/../../commit/a16caa8))

#### Bug Fixes

* Work around response_body issue on Rails 5, fix specs	 ([bc4ac76](/../../commit/bc4ac76))
* Return auth_time in ID token claims	 ([490f756](/../../commit/490f756))
* Don't require nonce	 ([d2945da](/../../commit/d2945da))
* Also support POST requests to userinfo	 ([87a6577](/../../commit/87a6577))
* Add openid scope to Doorkeeper configuration	 ([8169c2d](/../../commit/8169c2d))
