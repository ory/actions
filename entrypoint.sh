#!/bin/bash

set -Eeuox pipefail

args=$*

function dump() {
  echo "Failed running script."
  echo ""
  echo "  args:     ${args}"
  echo "  pwd:      $(pwd)"
  echo "  contents:"
  ls -lah
}

trap dump EXIT

eval $(ory dev ci github env)

/scripts/"$1".sh
