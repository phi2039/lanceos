
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
#   target
#   variant
#   configuration
#   tag
#
[arg("target", long="target")]
[arg("variant", long="variant")]
[arg("configuration", long="configuration")]
[arg("tag", long="tag")]
build target="server" variant="hci" configuration="nvidia" tag="stable":
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

    podman tag ${github_package_name}-${target_image}:${target_tag} \
        ghcr.io/${repo_organization}/${github_package_name}-${target_image}:${target_tag} \
        ghcr.io/${repo_organization}/${github_package_name}-${target_image}:${target_tag}.$(date -u +%Y\-%m\-%d)
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

    # Make sure the rootful Podman machine exists and is running
    just create-machine

    image_name=$(just get-image-name {{ target }} {{ variant }} {{ configuration }} {{ tag }})
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

    PODMAN_MACHINE_CONNECTION=${PODMAN_MACHINE_CONNECTION:-}

    # Determine Podman machine connection
    # TODO: Identify default instance that bootc-podman will select automatically?
    # ... or just set CONTAINER_CONNECTION?
    if [[ -z "$PODMAN_MACHINE_CONNECTION" ]]; then
        PODMAN_MACHINE_CONNECTION=$(podman system connection list --format '{{{{.Name}}\t{{{{.URI}}' | grep "root@" | awk '{print $1}')
    fi

    # Only copy image if not already present in Podman machine (compare build timestamps)
    local_created=$(podman inspect "${image_name}" --format '{{{{.Config.Labels}}' 2>/dev/null | grep -oP 'org\.opencontainers\.image\.created:\K[^ \]]+' || echo "")
    remote_created=$(podman --connection "${PODMAN_MACHINE_CONNECTION}" inspect "${image_name}" --format '{{{{.Config.Labels}}' 2>/dev/null | grep -oP 'org\.opencontainers\.image\.created:\K[^ \]]+' || echo "")

    if [[ -z "$local_created" ]]; then
        echo "Error: Local image '${image_name}' not found. Please build it first."
        exit 1
    fi

    if [[ "$local_created" != "$remote_created" ]]; then
        echo "Copying image '${image_name}' to rootful machine..."
        podman image scp ${image_name} ${PODMAN_MACHINE_CONNECTION}::
    else
        echo "Image '${image_name}' already exists on rootful machine with matching build timestamp. Skipping copy."
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
