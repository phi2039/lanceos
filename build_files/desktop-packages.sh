#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."

# TODO: Create scripts for packages requiring special installation handling (e.g. those that don't exist in repos)
# /ctx/desktop-1password.sh

# ublue staging and packages repos needed for misc packages provided by ublue
$DNF -y copr enable ublue-os/packages
$DNF -y copr enable ublue-os/staging

# VSCode
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Common packages installed to desktops
# TODO: define these lists in a JSON config file or similar
# See: https://github.com/bketelsen/homer/blob/main/build_files/packages-dx.sh
$DNF install --setopt=install_weak_deps=False -y \
    ccache \
    code \
    git \
    gnome-shell-extension-no-overview \
    libpcap-devel \
    libretls \
    ltrace \
    nerd-fonts \
    patch \
    powerline-fonts \
    rpmrebuild \
    sbsigntools \
    xorriso
