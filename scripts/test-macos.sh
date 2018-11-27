#! /usr/bin/env bash

xcodebuild -scheme Tasker-macOS -project Xcode/Tasker.xcodeproj test | xcpretty
