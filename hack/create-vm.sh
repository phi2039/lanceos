BUTANE_CONFIG=$1
BUTANE_CONFIG=$(realpath "${BUTANE_CONFIG}")
IMAGE=$2
VM_NAME=${3:-test-vm}
VCPUS="2"
RAM_MB="2048"
STREAM="stable"
DISK_GB="10"

IGNITION_CONFIG="${BUTANE_CONFIG%.bu}.ign"

IGNITION_DEVICE_ARG=(--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_CONFIG}")

echo "Generating ignition"
butane --pretty --strict "$BUTANE_CONFIG" --output "$IGNITION_CONFIG"
podman run --rm -i quay.io/coreos/ignition-validate:release - < $IGNITION_CONFIG

# Setup the correct SELinux label to allow access to the config
chcon --verbose --type svirt_home_t ${IGNITION_CONFIG}

virt-install --connect="qemu:///system" --name="${VM_NAME}" --vcpus="${VCPUS}" --memory="${RAM_MB}" \
        --os-variant="fedora-coreos-$STREAM" --import --graphics=none \
        --disk="size=${DISK_GB},backing_store=${IMAGE}" \
        --network bridge=virbr0 "${IGNITION_DEVICE_ARG[@]}"
