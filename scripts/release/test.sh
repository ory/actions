#!/bin/bash

set -Eeuox pipefail

curl -sSfL \
  "https://raw.githubusercontent.com/${GITHUB_ORG}/${GITHUB_REPO}/master/install.sh" \
  | sh -s "${GIT_TAG}"

"./bin/${GITHUB_REPO}" help
"./bin/${GITHUB_REPO}" version | grep -q "${GIT_TAG}" || exit 1
