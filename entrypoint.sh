#!/bin/bash

set -Eeuox pipefail

eval $(cli dev ci github env)

./scripts/"$1".sh
