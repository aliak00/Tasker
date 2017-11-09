!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    Example/Pods/SwiftFormat/CommandLineTool/swiftformat \
        Swooft/Sources/ Example/Tests  \
        --exclude Example/Pods/ \
        --comments ignore \
        --ranges nospace \
        --self insert \
        --indent 4 \
        --removelines enabled \
        --insertlines enabled \
        --allman false \
        --disable redundantReturn \
        --enable redundantGet \
        --enable spaceAroundBraces
fi
