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
    # TODO: Configure URLs centrally to handle version changes
    # INCUS_UI_URL=https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/incus-ui-canonical_6.20-debian13-202601150536_amd64.deb
    # wget $INCUS_UI_URL
    # INCUS_PKG=$(basename "$INCUS_UI_URL")
    # dpkg -x $INCUS_PKG ./incus-ui/
    # rsync -vaH incus-ui/opt/incus/. /usr/lib/opt/incus/
    # rm -rf $INCUS_PKG incus-ui/

# Alternative Incus UI installation method
    # Incus UI
    curl -Lo /tmp/incus-ui-canonical.deb \
        https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

    ar -x --output=/tmp /tmp/incus-ui-canonical.deb
    tar --zstd -xvf /tmp/data.tar.zst
    mv /opt/incus /usr/lib/
    sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/usr/lib/incus/ui/@g' /usr/lib/systemd/system/incus.service

    # Groups
    groupmod -g 250 incus-admin
    groupmod -g 251 incus
# end

    systemctl enable incus.service
    systemctl enable incus-init.service
fi

