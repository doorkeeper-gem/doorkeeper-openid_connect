# Doorkeeper::OpenidConnect

This library is a plugin to the Doorkeeper OAuth Ruby framework that implements the OpenID Connect specification incompletely (http://openid.net/specs/openid-connect-core-1_0.html).

## Installation

Add this line to your application's Gemfile:

    gem 'doorkeeper-openid_connect'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install doorkeeper-openid_connect

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

      issuer 'issuer string'

      resource_owner_from_access_token do |access_token|
        User.find(access_token.resource_owner_id)
      end

      subject do |resource_owner|
        resource_owner.key
      end

      email do |resource_owner|
        resource_owner.email
      end

    end

where:

* jws_private_key - private key for JSON Web Signature(https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31)
* jws_public_key  - public key for JSON Web Signature(https://tools.ietf.org/html/draft-ietf-jose-json-web-signature-31)
      issuer - REQUIRED. Issuer Identifier for the Issuer of the response. The iss value is a case sensitive URL using the https scheme that contains scheme, host, and optionally, port number and path components and no query or fragment components.
* resource_owner_from_access_token - defines how to translate the doorkeeper access_token to a resource owner model

Given a resource owner, the following claims are available:

* subject - REQUIRED. Subject Identifier. A locally unique and never reassigned identifier within the Issuer for the End-User, which is intended to be consumed by the Client, e.g., 24400320 or AItOawmwtWwcT0k51BayewNvutrJUqsvl6qs7A4. It MUST NOT exceed 255 ASCII characters in length. The sub value is a case sensitive string.
* email - resource owner email address
   
## TODO

1. Move jws_private_key and jws_public_key to a lamba expression to avoid committing keys to code
2. Available claims are hardcoded.  Enhance configuration to allow a hash of claims, each with their own lamba expression to determine value

## Contributing

1. Fork it ( http://github.com/<my-github-username>/doorkeeper-openid_connect/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
