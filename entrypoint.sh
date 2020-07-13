#!/bin/bash

set -Eeuox pipefail

eval $(ory dev ci github env)

./scripts/"$1".sh
