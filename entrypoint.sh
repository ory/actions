#!/bin/bash

set -Eeuox pipefail

echo "Running script: $*"

eval $(ory dev ci github env)

./scripts/"$1".sh
