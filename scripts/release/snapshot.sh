#!/bin/bash

set -Eeuox pipefail

goreleaser build --snapshot --skip-publish --rm-dist
