!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    Example/Pods/SwiftFormat/CommandLineTool/swiftformat Sources/ Example/Tests  --exclude Example/Pods/ --comments ignore --ranges nospace --insertlines disabled --self insert
fi
