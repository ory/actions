#!/bin/bash

set -Eeuox pipefail

docker login --username "$DOCKER_USER" --password "$DOCKER_TOKEN"

goreleaser build --snapshot --skip-publish --rm-dist
