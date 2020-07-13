#!/bin/bash

set -Eeuox pipefail

function dump() {
  echo "Failed running script."
  echo ""
  echo "  args:     $1"
  echo "  pwd:      $(pwd)"
  echo "  contents:"
  ls -lah
}

trap dump EXIT

eval $(ory dev ci github env)

/scripts/"$1".sh
