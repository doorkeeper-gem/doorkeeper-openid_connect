# Doorkeeper::OpenidConnect

This library is a plugin to the Doorkeeper OAuth Ruby framework that implements the OpenID Connect specification incompletely (http://openid.net/specs/openid-connect-core-1_0.html).

## Version 1.x

This library is still pretty raw, but the latest changes are not backwards compatible with the 0.x version of the gem, so the version has been bumped to 1.x according to Semantic Versioning (http://semver.org/) conventions.

## Installation

Add this line to your application's Gemfile:

    gem 'doorkeeper-openid_connect', '~> 1.0.0'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install doorkeeper-openid_connect -v '~> 1.0.0'

## Usage

Add the following to your config/routes.rb:

    use_doorkeeper_openid_connect

Add the following to your config/initializers/doorkeeper_openid_connect.rb:

    Doorkeeper::OpenidConnect.configure do

      jws_private_key <<eol
    -----BEGIN RSA PRIVATE KEY-----
    ....
    -----END RSA PRIVATE KEY-----
    eol

      jws_public_key <<eol
    -----BEGIN RSA PUBLIC KEY-----
    ....
    -----END RSA PUBLIC KEY-----
    eol

      resource_owner_from_access_token do |access_token|
        # Example implementation:
        # User.find_by(id: access_token.resource_owner_id)
      end

      issuer 'issuer string'

      subject do |resource_owner|
        # Example implementation:
        # resource_owner.key
      end

      # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
      # expiration 600

      claims do
        claim :_foo_ do |resource_owner|
          resource_owner.foo
        end

        claim :_bar_ do |resource_owner|
          resource_owner.bar
        end
      end

    end

where:

The following configurations are required:

* jws_private_key - private key for JSON Web Signature(https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31)
* jws_public_key  - public key for JSON Web Signature(https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31)
* resource_owner_from_access_token - defines how to translate the doorkeeper access_token to a resource owner model

Given a resource owner, the following claims are required:

* issuer - REQUIRED. Issuer Identifier for the Issuer of the response. The iss value is a case sensitive URL using the https scheme that contains scheme, host, and optionally, port number and path components and no query or fragment components.
* subject - REQUIRED. Subject Identifier. A locally unique and never reassigned identifier within the Issuer for the End-User, which is intended to be consumed by the Client, e.g., 24400320 or AItOawmwtWwcT0k51BayewNvutrJUqsvl6qs7A4. It MUST NOT exceed 255 ASCII characters in length. The sub value is a case sensitive string.

Exp claim can optionally be specified by expiration configuration.

* exp - REQUIRED. Expiration time on or after which the ID Token MUST NOT be accepted for processing. The processing of this parameter requires that the current date/time MUST be before the expiration date/time listed in the value. Implementers MAY provide for some small leeway, usually no more than a few minutes, to account for clock skew. Its value is a JSON number representing the number of seconds from 1970-01-01T0:0:0Z as measured in UTC until the date/time. See RFC 3339 [RFC3339] for details regarding date/times in general and UTC in particular.
    * Default 120 seconds

Custom claims can optionally be specified in a `claims` block.  The following claim types are currently supported:

* normal_claim - Normal claims (http://openid.net/specs/openid-connect-core-1_0.html#NormalClaims) - specify claim name and a block using resource_owner to determine the claim value.

## TODO

1. Move jws_private_key and jws_public_key to a lamba expression to avoid committing keys to code

## Contributing

1. Fork it ( http://github.com/<my-github-username>/doorkeeper-openid_connect/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Sponsors

Initial development of this project was sponsored by PlayOn! Sports.

