#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

# Copy system files
rsync -rvK /ctx/system_files/server/ /

if [[ ${IMAGE} =~ ucore-hci ]]; then
    rsync -rvK /ctx/system_files/server-hci/ /
fi

echo "Tweaking existing server config..."

# ensure no moby-engine packages, we can use sysext if needed
$DNF remove -y containerd docker-buildx docker-cli docker-compose moby-engine runc

# Disable unneeded services
systemctl disable zincati.service

# Enable needed services
systemctl enable cockpit.service
systemctl enable podman.socket
