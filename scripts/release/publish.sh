#!/bin/bash

set -Eeuox pipefail

docker login --username "$DOCKER_USER" --password "$DOCKER_TOKEN"

export GORELEASER_CURRENT_TAG="${GIT_TAG}"

if [[ ! -e package.json ]]; then
  echo '{"private": true, "version": "0.0.0"}' > package.json
  git add package.json
else
  echo "package.json exists and needs not be written"
fi

changelog=$(mktemp)
notes=$(mktemp)
preset=$(mktemp -d)

npm --no-git-tag-version version "$GIT_TAG"
git clone git@github.com:ory/changelog.git "$preset"
(cd "$preset"; npm i)

git tag -l --format='%(contents)' "$GIT_TAG" > "$notes"
npx conventional-changelog-cli@v2.0.34 --config "$preset/index.js" -r 2 -o "$changelog"

printf "\n\n" >> "$notes"
cat "$changelog" >> "$notes"

git reset --hard HEAD
goreleaser release --release-header <(cat "$notes") --rm-dist
