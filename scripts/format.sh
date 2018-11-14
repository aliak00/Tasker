!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat \
        Swooft/Sources/ Example/Tests  \
        --exclude Example/Pods/ \
        --comments ignore \
        --ranges nospace \
        --self insert \
        --indent 4 \
        --removelines enabled \
        --insertlines enabled \
        --allman false \
        --enable redundantGet \
        --enable spaceAroundBraces
fi
