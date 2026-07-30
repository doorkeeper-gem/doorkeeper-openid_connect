#!/usr/bin/env bash
#
# Decides whether the eager-load job has to run for the current event, and
# writes the answer to $GITHUB_OUTPUT as `run=true|false`.
#
# The check itself boots a Rails application seven times over, so it is not
# worth paying for on a README typo. It only earns its keep when something
# could have changed which files get loaded.

set -eu

decide() {
  echo "run=$1" >>"$GITHUB_OUTPUT"
  echo "$2 (run=$1)"
  exit 0
}

if [ "${LABELLED:-false}" = "true" ]; then
  decide true "Requested through the eager-load-check label."
fi

if [ "$EVENT" != "pull_request" ]; then
  # A push to the default branch is the safety net for anything that lands
  # without a pull request; every other push already has its own PR event.
  if [ "${GITHUB_REF_NAME:-}" = "${DEFAULT_BRANCH:-}" ]; then
    decide true "Push to the default branch."
  fi

  decide false "Not a pull request, and not the default branch."
fi

# The check's own moving parts. A change here has to be exercised, if only to
# prove the check still runs at all.
if ! git diff --quiet "$BASE_SHA" HEAD -- \
  bin/eager-load-check \
  Rakefile \
  .github/workflows/eager_load.yml \
  .github/scripts/eager-load-needed.sh \
  spec/dummy/config/environments/test.rb; then
  decide true "The eager-load check's own files changed."
fi

# Additions, deletions and renames under the loaded source trees. Any of the
# three can leave a file that nothing loads any more, or a new file that
# nothing loads yet.
name_status=$(git diff --name-status -M "$BASE_SHA" HEAD -- lib app)
if grep -qE '^(A|D|R)' <<<"$name_status"; then
  decide true "Files were added, removed or renamed under lib/ or app/."
fi

# Touched require / autoload lines. `-U0` keeps context lines out of the
# comparison so that only real edits count.
touched=$(git diff -U0 "$BASE_SHA" HEAD -- lib app | grep -E '^[-+]' || true)
if grep -qE '(^|[^_[:alnum:]])(require(_relative)?|autoload)([^_[:alnum:]]|$)' <<<"$touched"; then
  decide true "require / autoload lines changed under lib/ or app/."
fi

decide false "Nothing that can change which files get loaded."
