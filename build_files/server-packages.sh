#!/usr/bin/env bash

# TODO: Rebase ublue-homelab machine from this repo

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

$DNF -y install cockpit-ostree

# Install packages and dependencies
if [[ ${VARIANT_NAME} =~ hci ]]; then
    $DNF install -y \
        lxc \
        dpkg \
        binutils \
        incus \
        incus-tools \
        kubectl

    # Incus WebUI
    INCUS_UI_URL=https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"
    wget $INCUS_UI_URL
    INCUS_PKG=$(basename "$INCUS_UI_URL")
    dpkg -x $INCUS_PKG ./incus-ui/
    rsync -vaH incus-ui/opt/incus/. /usr/lib/opt/incus/
    rm -rf $INCUS_PKG incus-ui/
fi
