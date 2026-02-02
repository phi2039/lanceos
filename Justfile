
export default_tag := env("DEFAULT_TAG", "latest")

export repo_organization := env("GITHUB_REPOSITORY_OWNER", "phi2039")
export os_name := env("OS_NAME", "lanceos")

export github_package_name := "lanceos"
repo_name := "phi2039"

export SUDO_DISPLAY := if `if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then echo true; fi` == "true" { "true" } else { "false" }
export SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY == "true" { "sudo --askpass" } else { "sudo" }
export SET_X := if `id -u` == "0" { "1" } else { env('SET_X', '') }

[private]
default:
    @just --list

# Build a container image using Podman.
#
# Arguments:
#   $target
#   $variant
#   $configuration
#   $tag
#
# WIP
build $target="server" $variant="hci" $configuration="nvidia" $tag="stable":
    #!/usr/bin/env bash

    set ${SET_X:+-x} -eou pipefail

    IMAGE_DESCRIPTOR=$(just get-image-descriptor {{ target }} {{ variant }} {{ configuration }} {{ tag }})
    echo IMAGE_DESCRIPTOR: $IMAGE_DESCRIPTOR
    BUILD_ARGS=()
    
    target_image=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".image_name")
    target_tag=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".tag")

    upstream_image=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".upstream_image")
    upstream_tag=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".upstream_tag")

    target_name=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".target")
    variant_name=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".variant")
    configuration_name=$(echo "$IMAGE_DESCRIPTOR" | jq -r ".configuration")

    # TODO: Validate paramaters
    # if [[ -z $image ]]; then
    #     echo "Possible typo. The image '$target_image' did not exist in 'images.yml'."
    #     exit 1
    # fi

    BUILD_ARGS+=("--build-arg" "UPSTREAM_IMAGE=${upstream_image}")
    BUILD_ARGS+=("--build-arg" "UPSTREAM_TAG=${upstream_tag}")

    BUILD_ARGS+=("--build-arg" "TARGET_NAME=${target_name}")
    BUILD_ARGS+=("--build-arg" "VARIANT_NAME=${variant_name}")
    BUILD_ARGS+=("--build-arg" "CONFIGURATION_NAME=${configuration_name}")
    BUILD_ARGS+=("--build-arg" "TARGET_TAG=${target_tag}")

    # Include SHA if working directory is clean
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    # Labels
    LABELS=()
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)")
    LABELS+=("--label" "org.opencontainers.image.description=${IMAGE_DESC:+""}")
    LABELS+=("--label" "org.opencontainers.image.documentation=https://raw.githubusercontent.com/${repo_organization}/${github_package_name}-${target_image}/refs/heads/main/README.md")
    LABELS+=("--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/${repo_organization}/${github_package_name}-${target_image}/refs/heads/main/Containerfile")
    LABELS+=("--label" "org.opencontainers.image.title=${github_package_name}-${target_image}")
    LABELS+=("--label" "org.opencontainers.image.url=https://github.com/${repo_organization}/${github_package_name}-${target_image}")
    LABELS+=("--label" "org.opencontainers.image.vendor=${repo_organization}")
    LABELS+=("--label" "org.opencontainers.image.version=${github_package_name}-${target_image}.$(date -u +%Y\-%m\-%d)")
    LABELS+=("--label" "containers.bootc=1")

    podman build \
        --file Containerfile \
        "${BUILD_ARGS[@]}" \
        "${LABELS[@]}" \
        --pull=newer \
        --tag "${github_package_name}-${target_image}:${target_tag}" \
        {{ justfile_dir() }}

    # podman tag ${github_package_name}-${target_image}:${target_tag} \
    #     ghcr.io/${repo_organization}/${github_package_name}-${target_image}:${target_tag} \
    #     ghcr.io/${repo_organization}/${github_package_name}-${target_image}:${target_tag}.$(date -u +%Y\-%m\-%d)
    podman images "${github_package_name}-${target_image}"

# Create or start a Podman Machine instance
[group('Run Virtal Machine')]
create-machine $machine_name="podman-machine-default":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    echo "Checking for rootful Podman machine '$machine_name'..."
    if podman machine inspect podman-machine-default &> /dev/null; then
        if podman machine list --format '{{{{.Name}}\t{{{{.Running}}' | grep -w "$machine_name" | grep -w "true"; then
            echo "Rootful machine exists and is running."
            exit 0
        fi
        echo "Rootful machine already exists but is not running...starting it"
        podman machine start $machine_name
    else
        echo "Creating rootful machine '$machine_name'..."
        podman machine init --rootful --now $machine_name
    fi

# Run a virtual machine using Podman and QEMU
[group('Run Virtal Machine')]
[arg("replace", long="replace", value="true", help="Replace exiting VM instead of erroring out")]
run-vm $target="server" $variant="hci" $configuration="nvidia" $tag="stable" replace="false":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    PODMAN_MACHINE_CONNECTION=${PODMAN_MACHINE_CONNECTION:-}

    # Make sure the rootful Podman machine exists and is running
    just create-machine

    # Determine Podman machine connection
    # TODO: Identify default instance that bootc-podman will select automatically?
    # ... or just set CONTAINER_CONNECTION?
    if [[ -z "$PODMAN_MACHINE_CONNECTION" ]]; then
        PODMAN_MACHINE_CONNECTION=$(podman system connection list --format '{{{{.Name}}\t{{{{.URI}}' | grep "root@" | awk '{print $1}')
    fi

    # TODO: Build image if not present
    # TODO: Only copy image if not already present in Podman machine
    image_name=$(just get-image-name {{ target }} {{ variant }} {{ configuration }} {{ tag }})
    local_image_info=$(podman --connection podman-machine-default image inspect ${image_name} --format '{{{{index .Config.Labels "ostree.final-diffid"}}')
    # rootful_image_info=$(podman --connection $PODMAN_MACHINE_CONNECTION image inspect ${image_name} --format '{{{{index .Config.Labels "ostree.final-diffid"}}') || true
    rootful_image_info=false
    if [[ "$local_image_info" != "$rootful_image_info" ]]; then
        echo "Image digests differ or image not found in Podman machine, copying image..."
        podman image scp ${image_name} ${PODMAN_MACHINE_CONNECTION}::
    else
        echo "Image already present in Podman machine with matching digest."
    fi

    # Check for already-running VM and kill it before starting a new one or exit
    POD_ID=$(podman-bootc list | grep "$image_name " | awk '{print $1}') || true
    if [[ ! -z $POD_ID ]]; then
        echo "VM for image '$image_name' is already running."
        if [[ "{{replace}}" == "true" ]]; then
            echo "Removing existing VM..."
            podman-bootc rm $POD_ID --force
        else
            echo "Use --replace to remove existing VM."
            exit 0
        fi
    fi
    echo "Starting VM for image '$image_name'..."
    podman-bootc run --background --filesystem xfs localhost/${image_name}

# Connect to a running Podman bootc VM
[group('Run Virtal Machine')]
connect-vm $target="server" $variant="hci" $configuration="nvidia" $tag="stable":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    image_name=$(just get-image-name {{ target }} {{ variant }} {{ configuration }} {{ tag }})
    POD_ID=$(podman-bootc list | grep "$image_name " | awk '{print $1}')
    if [[ -z $POD_ID ]]; then
        echo "No running VM found for image '$image_name'."
        exit 1
    fi
    podman-bootc ssh $POD_ID

[group('Run Virtal Machine')]
stop-vm $target="server" $variant="hci" $configuration="nvidia" $tag="stable":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    image_name=$(just get-image-name {{ target }} {{ variant }} {{ configuration }} {{ tag }})

    POD_ID=$(podman-bootc list | grep "$image_name " | awk '{print $1}')
    if [[ -z $POD_ID ]]; then
        echo "No running VM found for image '$image_name'."
        exit 1
    fi
    podman-bootc stop $POD_ID

[arg("force", long="force", value="true", help="Force removal of the VM")]
remove-vm $target="server" $variant="hci" $configuration="nvidia" $tag="stable" force:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    image_name=$(just get-image-name {{ target }} {{ variant }} {{ configuration }} {{ tag }})

    POD_ID=$(podman-bootc list | grep "$image_name " | awk '{print $1}')
    if [[ -z $POD_ID ]]; then
        echo "No running VM found for image '$image_name'."
        exit 1
    fi
    echo {{force}}
    podman-bootc rm $POD_ID $(if [[ "{{force}}" == "true" ]]; then echo "--force"; fi)

#TODO: Create recipe to start VM if not running

#TODO: Create recipe to clean-up VMs

# Generate an image name from target, variant, configuration, and tag
# Returns: {os_name}-{target}[-{variant}][-{configuration}][:{tag}]
# Empty variant/configuration are omitted from the name
[group('Utility')]
get-image-name target="server" variant="hci" configuration="nvidia" tag="stable":
    #!/usr/bin/env bash
    set -eou pipefail
    name="{{ os_name }}-{{ target }}"
    if [[ -n "{{ variant }}" ]]; then
        name="${name}-{{ variant }}"
    fi
    if [[ -n "{{ configuration }}" ]]; then
        name="${name}-{{ configuration }}"
    fi
    if [[ -n "{{ tag }}" ]]; then
        name="${name}:{{ tag }}"
    fi
    echo "${name}"

#TODO: Remove dependency on external script...
# Generate an image descriptor from target, variant, configuration, and tag
# Returns: JSON object with image_name, tag, upstream_image, upstream_tag, target,
[group('Utility')]
get-image-descriptor target variant="hci" configuration="nvidia" tag="stable":
    #!/usr/bin/env bash
    set -eou pipefail
    . utils/flatten-images.sh
    image_descriptor=$(get_image_descriptor "{{ target }}" "{{ variant }}" "{{ configuration }}" "{{ tag }}")
    echo "${image_descriptor}"

# Runs shell check on all Bash scripts
[group('Utility')]
lint:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
[group('Utility')]
format:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Get Cosign if Needed
    if [[ ! $(command -v cosign) ]]; then
        COSIGN_CONTAINER_ID=$({{ SUDOIF }} podman create ghcr.io/sigstore/cosign/cosign:v2.6.1 bash)
        {{ SUDOIF }} podman cp "${COSIGN_CONTAINER_ID}":/ko-app/cosign /usr/local/bin/cosign
        {{ SUDOIF }} podman rm -f "${COSIGN_CONTAINER_ID}"
    fi

    # Verify Cosign Image Signatures if needed
    if [[ -n "${COSIGN_CONTAINER_ID:-}" ]]; then
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
    fi

    # Public Key for Container Verification
    key={{ key }}
    if [[ -z "${key:-}" && "{{ registry }}" == "ghcr.io/ublue-os" ]]; then
        key="https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub"
    fi

    # Verify Container using cosign public key
    if ! cosign verify --key "${key}" "{{ registry }}"/"{{ container }}" >/dev/null; then
        echo "NOTICE: Verification failed. Please ensure your public key is correct."
        exit 1
    fi

    # Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/env bash
    #!/usr/bin/bash/
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.
# TODO: Extract the useful bits from this
_rootful_load_image $target_image=os_name $tag=default_tag:
    #!/usr/bin/env bash
    # set -eoux pipefail

    # # Check if already running as root or under sudo
    # if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
    #     echo "Already root or running under sudo, no need to load image from user podman."
    #     exit 0
    # fi

    # # Try to resolve the image tag using podman inspect
    # set +e
    # resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    # return_code=$?
    # set -e

    # USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    # if [[ $return_code -eq 0 ]]; then
    #     # If the image is found, load it into rootful podman
    #     ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
    #     if [[ "$ID" != "$USER_IMG_ID" ]]; then
    #         # If the image ID is not found or different from user, copy the image from user podman to root podman
    #         COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
    #         just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
    #         rm -rf "${COPYTMP}"
    #     fi
    # else
    #     # If the image is not found, pull it from the repository
    #     just sudoif podman pull "${target_image}:${tag}"
    # fi
