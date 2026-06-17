# Doorkeeper OpenID Connect Agent Guide

This repository is the `doorkeeper-openid_connect` gem: a Rails engine that adds OpenID Connect behavior on top of the Doorkeeper OAuth 2 provider.

## What this codebase does

- Extends Doorkeeper grant flows and token responses for OIDC (`lib/doorkeeper/openid_connect.rb`, `lib/doorkeeper/openid_connect/oauth/**`)
- Implements OIDC configuration and claims handling (`lib/doorkeeper/openid_connect/config.rb`, `lib/doorkeeper/openid_connect/claims**`)
- Exposes OIDC endpoints through engine controllers (`app/controllers/doorkeeper/openid_connect/**`)
- Provides discovery, UserInfo, and dynamic client registration support
- Supports ActiveRecord only; non-ActiveRecord ORMs are intentionally rejected in `Doorkeeper::OpenidConnect.configure`

## Important working rules

- Treat OAuth 2.0 and OpenID Connect specs as the source of truth. Prefer spec-compliant behavior over app-specific convenience.
- Preserve compatibility with supported Doorkeeper / Rails versions. CI runs this gem against multiple `gemfiles/*.gemfile`, so avoid assumptions tied to a single Rails version.
- Keep changes small and localized. Most behavior belongs in `lib/doorkeeper/openid_connect/**`; controller-facing endpoint behavior belongs under `app/controllers/doorkeeper/openid_connect/**`.
- Add or update specs with behavior changes. This project relies on RSpec and the dummy Rails app under `spec/dummy`.
- When changing configuration surface area, update all relevant places together:
  - runtime config in `lib/doorkeeper/openid_connect/config.rb`
  - initializer template in `lib/generators/doorkeeper/openid_connect/templates/initializer.rb`
  - README configuration docs
  - specs covering the option

## Repo layout

- `lib/doorkeeper/openid_connect.rb`: main entrypoint, grant flow registration, issuer resolution
- `lib/doorkeeper/openid_connect/config.rb`: config options and defaults
- `lib/doorkeeper/openid_connect/oauth/**`: request/response and authorization flow extensions
- `lib/doorkeeper/openid_connect/orm/active_record/**`: ActiveRecord mixins and models
- `app/controllers/doorkeeper/openid_connect/**`: discovery, userinfo, dynamic registration endpoints
- `spec/**`: test suite
- `spec/dummy/**`: Rails app used by controller/integration-style specs

## Test and lint commands

Run from the repository root:

```bash
bundle exec rake spec
bundle exec rubocop
```

Notes:

- The default `Gemfile` uses `ENV["rails"]` and defaults to Rails `8.0.0`.
- CI runs `bundle exec rake spec` across the matrix in `.github/workflows/ci.yml`.
- Use the root-level test command unless a task specifically requires a different `BUNDLE_GEMFILE`.

## Change expectations

### Changelog

For user-facing fixes and features, add an entry at the top of `CHANGELOG.md` under `## Unreleased`.

Format entries like:

```md
- [#123] Brief description
```

Use the existing entries as the style reference.

### Documentation

- Keep README examples aligned with the current initializer template and config behavior.
- Use YARD/RDoc-style comments for API-level Ruby documentation when needed.

### Specs

- Prefer updating the closest existing spec file instead of creating redundant coverage.
- Controller and request-flow behavior is usually exercised through the dummy app configuration in `spec/dummy/config/initializers/**`.
- If you change OIDC claims, flows, or config arity/behavior, inspect existing specs before adding new helpers or patterns.

## Project-specific cautions

- Do not weaken security-sensitive behavior around issuer resolution, signing keys, token response contents, client authentication, or dynamic client registration.
- Do not introduce non-ActiveRecord support unless explicitly requested; the gem currently enforces ActiveRecord.
- Do not treat dummy-app secrets or keys as production guidance; they exist only for tests.
- If you change supported metadata or discovery output, check both spec coverage and README documentation.
