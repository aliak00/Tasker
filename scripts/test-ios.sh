#! /usr/bin/env bash

set -e
set -o pipefail

xcodebuild -scheme Tasker-iOS \
    -project Xcode/Tasker.xcodeproj \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 7,OS=12.4' \
    test | xcpretty
