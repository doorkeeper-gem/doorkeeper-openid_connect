[![Gem Version](https://badge.fury.io/rb/gollum-rugged_adapter.svg)](http://badge.fury.io/rb/gollum-rugged_adapter)
[![Build Status](https://travis-ci.org/gollum/rugged_adapter.svg?branch=master)](https://travis-ci.org/gollum/rugged_adapter)

## DESCRIPTION

Adapter for [gollum](https://github.com/gollum/gollum) to use [Rugged](https://github.com/libgit2/rugged) (libgit2) at the backend. See the [gollum wiki](https://github.com/gollum/gollum/wiki/Git-adapters) for more information on adapters. Currently gollum uses grit as a backend by default, but since that is abandonware, the plan is to make this adapter the default in the future.

**Please note that this adapter is currently in beta. It passes the unit tests for gollum and [gollum-lib](https://github.com/gollum/gollum-lib), but it needs more comprehensive testing. Please [report any issues](https://github.com/gollum/rugged_adapter/issues) that you encounter.**

## USAGE

Install the gem:

`gem install gollum-rugged_adapter`

Now run gollum as follows:

`gollum --adapter rugged`

## CONTRIBUTING

1. Start by cloning the repo [on GitHub](http://github.com/gollum/rugged_adapter).
2. From inside the repo's directory, install the (development) dependencies with `bundle install`
3. Create a thoughtfully named topic branch to contain your changes.
4. Hack away.
5. Make sure your changes pass the adapter's specs: `bundle exec rake`
6. Make sure your changes pass gollum-lib's tests
  * Clone [gollum-lib](https://github.com/gollum/gollum-lib) and add your local version of the rugged adapter to the gollum-lib `Gemfile`:
  
  `gem gollum-rugged_adapter, :path => '/path/to/rugged_adapter'`
  * `bundle install`
  * `bundle exec rake GIT_ADAPTER=rugged`
1. If necessary, rebase your commits into logical chunks, without errors.
1. Push the branch up to GitHub.
1. Send a pull request to the gollum/rugged_adapter project.

## RELEASING

This gem uses [Semantic Versioning](http://semver.org/).
