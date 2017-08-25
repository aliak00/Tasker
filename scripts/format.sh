!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    Example/Pods/SwiftFormat/CommandLineTool/swiftformat Swooft/Sources/ Example/Tests  --exclude Example/Pods/ --comments ignore --ranges nospace --insertlines disabled --self insert
fi
