#!/bin/bash

set -Eeuox pipefail

goreleaser build --snapshot --rm-dist
