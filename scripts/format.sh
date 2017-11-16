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
        --enable redundantGet \
        --enable spaceAroundBraces \
        --header "\
\n\
 Copyright {year} Ali Akhtarzada\n\
\n\
 Licensed under the Apache License, Version 2.0 (the 'License');\n\
 you may not use this file except in compliance with the License.\n\
 You may obtain a copy of the License at\n\
\n\
 http://www.apache.org/licenses/LICENSE-2.0\n\
"
fi
