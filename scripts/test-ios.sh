#! /usr/bin/env bash

xcodebuild -scheme Tasker-iOS \
    -project Xcode/Tasker.xcodeproj \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 5s,OS=12.2' \
    test | xcpretty
