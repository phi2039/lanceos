#!/usr/bin/env bash

# TODO: Rebase ublue-homelab machine from this repo

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

$DNF -y install cockpit-ostree

# Install packages and dependencies
if [[ ${IMAGE} =~ ucore-hci ]]; then
    $DNF install -y \
        lxc \
        dpkg \
        incus \
        incus-tools \
        kubectl \
        k3s-selinux

    # Incus WebUI
    # TODO: Configure URLs centrally to handle version changes
    INCUS_UI_URL=https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/incus-ui-canonical_6.20-debian13-202601150536_amd64.deb
    wget $INCUS_UI_URL
    INCUS_PKG=$(basename "$INCUS_UI_URL")
    dpkg -x $INCUS_PKG ./incus-ui/
    rsync -vaH incus-ui/opt/incus/. /usr/lib/opt/incus/
    rm -rf $INCUS_PKG incus-ui/

    systemctl enable incus.service
    systemctl enable incus-init.service

# Alternative Incus UI installation method
    # $DNF install -y incus

    # Incus UI
    # curl -Lo /tmp/incus-ui-canonical.deb \
    #     https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

    # ar -x --output=/tmp /tmp/incus-ui-canonical.deb
    # tar --zstd -xvf /tmp/data.tar.zst
    # mv /opt/incus /usr/lib/
    # sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/usr/lib/incus/ui/@g' /usr/lib/systemd/system/incus.service

    # Groups
    # groupmod -g 250 incus-admin
    # groupmod -g 251 incus
# end

    # k3s
    # TODO: Configure URLs centrally to handle version changes
    K3S_URL=https://github.com/k3s-io/k3s/releases/download/v1.27.10%2Bk3s2/k3s
    wget $K3S_URL -O /usr/local/bin/k3s
    chmod 755 /usr/local/bin/k3s

    systemctl enable k3s.service
fi

