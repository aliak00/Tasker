#! /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat \
        Sources/ Tests/  \
        --swiftversion 5.2 \
        --nospaceoperators \
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
        --disable isEmpty \
        --header strip
fi
