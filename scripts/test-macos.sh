#! /usr/bin/env bash

set -e
set -o pipefail

xcodebuild -scheme Tasker-macOS -project Xcode/Tasker.xcodeproj test | bundle exec xcpretty
