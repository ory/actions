#!/bin/bash

set -Eeuox pipefail

if [ -z ${GIT_TAG+x} ]; then
  exit 0
elif [[ "$(git show -s --format=%B | head -n 1)" == "autogen"* ]]; then
  exit 0
fi

# Do not escape $SWAGGER_SPEC_IGNORE_PKGS with `"`!!
swagger generate spec -m -o "$SWAGGER_SPEC_PATH" -x "$SWAGGER_SPEC_IGNORE_PKGS"

ory dev swagger sanitize "$SWAGGER_SPEC_PATH"
swagger flatten --with-flatten=remove-unused -o "$SWAGGER_SPEC_PATH" "$SWAGGER_SPEC_PATH"
swagger validate "$SWAGGER_SPEC_PATH"

rm -rf "$SWAGGER_SDK_DESTINATION"
mkdir -p "$SWAGGER_SDK_DESTINATION"

swagger generate client -f "$SWAGGER_SPEC_PATH" -t "$SWAGGER_SDK_DESTINATION" -A "$SWAGGER_APP_NAME"

git add -A
(git commit -m "autogen(openapi): Regenerate swagger spec and internal client" -a \
  && git push origin "HEAD:$GIT_BRANCH") \
  || true
