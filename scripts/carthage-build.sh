#! /usr/bin/env bash

set -e

carthage build --no-skip-current --platform ios
carthage build --no-skip-current --platform macOS
