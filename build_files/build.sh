#!/bin/bash

set -ouex pipefail

# TODO: Refactor scripts into "packages" organized by application (branch in each to handle variations by target image)
# Version-specific changes and packages
case "${TARGET_NAME}" in
"server"*)
    echo "::group:: ===Server Changes==="
    /ctx/build_files/server-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Server Packages==="
    /ctx/build_files/server-packages.sh
    echo "::endgroup::"
    ;;
"desktop"*)
    echo "::group:: ===Desktop Changes==="
    /ctx/build_files/desktop-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/build_files/desktop-packages.sh
    echo "::endgroup::"
    ;;
"gaming"*)
    # echo "::group:: ===Gaming Changes==="
    # /ctx/build_files/gaming-changes.sh
    # echo "::endgroup::"

    # echo "::group:: ===Gaming Packages==="
    # /ctx/build_files/gaming-packages.sh
    # echo "::endgroup::"
    ;;
esac

# Common changes and packages
echo "::group:: ===Common Changes==="
/ctx/build_files/common-changes.sh
echo "::endgroup::"

echo "::group:: ===Common Packages==="
/ctx/build_files/common-packages.sh
echo "::endgroup::"

#echo "::group:: ===Branding Changes==="
#/ctx/build_files/branding.sh
#echo "::endgroup::"

# echo "::group:: ===Container Signing==="
# /ctx/build_files/configure-signing.sh
# echo "::endgroup::"

# Clean Up
echo "::group:: ===Cleanup==="
/ctx/build_files/cleanup.sh
echo "::endgroup::"
