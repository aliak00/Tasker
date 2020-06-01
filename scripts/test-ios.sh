#! /usr/bin/env bash

set -e
set -o pipefail

xcodebuild -scheme Tasker-iOS \
    -project Xcode/Tasker.xcodeproj \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 11,OS=13.5' \
    test | bundle exec xcpretty
