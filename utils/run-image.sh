# podman run --rm --privileged --pid=host \
#     -v /var/lib/containers:/var/lib/containers \
#     -v /dev:/dev \
#     --security-opt label=type:unconfined_t \
#     ghcr.io/phi2039/lanceos \
#         bootc install to-disk /path/to/disk

sudo rpm-ostree install --apply-live 'podman-bootc >= 0.5.0'

podman machine init --rootful --now podman-machine-default
# OR
podman machine start podman-machine-default

# Change $PWD (Containerfile location) as appropriate
podman -c podman-machine-default build -t ghcr.io/phi2039/lanceos/latest $PWD

podman-bootc run --background --filesystem xfs ghcr.io/phi2039/lanceos-server-hvi-nvidia:stable
POD_ID=$(podman-bootc list | awk 'NR > 1 {print $1}')
podman-bootc ssh $POD_ID

POD_ID=$(podman-bootc list | awk 'NR > 1 {print $1}')
podman-bootc stop $POD_ID
# OR
POD_ID=$(podman-bootc list | awk 'NR > 1 {print $1}')
podman-bootc rm $POD_ID --force

podman-bootc rm --all
