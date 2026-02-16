#!/usr/bin/env bash

# TODO: Rebase ublue-homelab machine from this repo

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

$DNF -y install cockpit-ostree

curl --fail --retry 5 --retry-delay 5 --retry-all-errors -sL https://github.com/coder/coder/releases/download/v2.29.6/coder_2.29.6_linux_amd64.rpm -o coder_2.29.6_linux_amd64.rpm
$DNF -y install ./coder_2.29.6_linux_amd64.rpm
rm coder_2.29.6_linux_amd64.rpm

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
