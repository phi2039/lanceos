#!/usr/bin/env bash

# TODO: Rebase ublue-homelab machine from this repo

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

$DNF -y install cockpit-ostree

CODER_FALLBACK_VERSION="v2.30.4"
CODER_REPO_NAME="coder/coder"
CODER_VERSION=$(curl --silent "https://api.github.com/repos/$CODER_REPO_NAME/releases/latest" | jq -r .tag_name)
if [[ "$CODER_VERSION" == "null" || "$CODER_VERSION" == "" ]]; then CODER_VERSION=$CODER_FALLBACK_VERSION ; fi

CODER_VERSION_REGEX="([0-9]{1,2})\\.([0-9]{1,2})\\.([0-9]{1,2})"
if [[ "$CODER_VERSION" =~ $CODER_VERSION_REGEX ]]; then
    CODER_RELEASE_URL="https://github.com/coder/coder/releases/download/$CODER_VERSION/coder_${BASH_REMATCH[0]}_linux_amd64.rpm"
    CODER_RPM_FILE="coder_${BASH_REMATCH[0]}_linux_amd64.rpm"
    echo "Detected Coder version: ${BASH_REMATCH[0]}"
else
    echo "Unable to identify Coder release"
fi

curl --fail --retry 5 --retry-delay 5 --retry-all-errors -sL $CODER_RELEASE_URL -o $CODER_RPM_FILE
echo "Downloaded $CODER_RPM_FILE"
$DNF -y install "./$CODER_RPM_FILE"
rm $CODER_RPM_FILE

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
