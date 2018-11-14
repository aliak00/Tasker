!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat \
        Sources/ Tests  \
        --comments ignore \
        --ranges nospace \
        --self insert \
        --indent 4 \
        --allman false \
        --enable redundantGet \
        --enable spaceAroundBraces \
        --header strip
fi
