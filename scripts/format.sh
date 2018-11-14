!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat \
        Sources/ Tests/  \
        --comments ignore \
        --ranges nospace \
        --self insert \
        --indent 4 \
        --allman false \
        --enable redundantGet \
        --enable redundantLet \
        --enable redundantReturn \
        --enable spaceAroundBraces \
        --enable spaceInsideBraces \
        --enable consecutiveBlankLines \
        --enable linebreakAtEndOfFile \
        --header strip
fi
