#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running common packages scripts..."

if [ -e /.git ]; then
    rm -fr /.git
fi

# Copy system files
rsync -rvK /ctx/system_files/common/ /
