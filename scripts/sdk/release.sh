#!/bin/bash

set -Eeuox pipefail

# Do not escape $SWAGGER_SPEC_IGNORE_PKGS with `"`!!
swagger generate spec -m -o "$SWAGGER_SPEC_PATH" $SWAGGER_SPEC_IGNORE_PKGS

ory dev swagger sanitize "$SWAGGER_SPEC_PATH"
swagger flatten --with-flatten=remove-unused -o "$SWAGGER_SPEC_PATH" "$SWAGGER_SPEC_PATH"
swagger validate "$SWAGGER_SPEC_PATH"

git clone git@github.com:ory/sdk.git ../sdk
cp "$SWAGGER_SPEC_PATH" "../sdk/spec/${GITHUB_REPO}/${GIT_TAG}.json"

(cd ../sdk; \
git add -A; git commit -a -m "Add spec for ${CIRCLE_PROJECT_REPONAME}:${CIRCLE_TAG}" || true; git push origin || true)
