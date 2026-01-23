#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running common packages scripts..."

# Common packages installed to desktops and servers
$DNF install -y \
    7zip \
    age \
    bc \
    binutils \
    cpp \
    hdparm \
    ipcalc \
    iperf3 \
    libsodium \
    lzip \
    netcat \
    nmap \
    numactl \
    nvtop \
    picocom \
    podman-tui \
    socat \
    udica \
    unrar-free \
    unzip \
    zip

# Frostyard Updex for systemd-sysext images
# TODO: Does this belong on both desktop and server?
/ctx/build_files/github-release-install.sh frostyard/updex $(uname -m).rpm

# TODO: Understand what is going on here
if getent group "docker" > /dev/null 2>&1; then
    # If "docker" exists in /usr/lib/group but not in /etc/group
    if ! grep -q "^docker:" /etc/group && grep -q "^docker:" /usr/lib/group; then
        # Add the group from /usr/lib/group to /etc/group
        grep "^docker:" /usr/lib/group >> /etc/group
    fi

    # If "docker" exists in /etc/group, modify the group ID
    if grep -q "^docker:" /etc/group; then
        groupmod -g 252 docker
    fi
fi
