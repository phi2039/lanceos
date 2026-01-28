#!/usr/bin/env bash
# Script to flatten images.yaml targets into a flat array of image descriptors
# Each descriptor contains the complete information needed to build/tag an image
#
# Can be run directly or sourced to use the get_image_descriptor function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_FILE="${IMAGES_FILE:-${SCRIPT_DIR}/../images.yaml}"

# Utility function to get image descriptor for a specific target/variant/configuration/tag
# Usage: get_image_descriptor TARGET [VARIANT] [CONFIGURATION] [TAG]
# Returns: Single JSON object descriptor for the specified combination
# If TAG is not specified, defaults to "testing"
get_image_descriptor() {
    local target="$1"
    local variant="${2:-}"
    local configuration="${3:-}"
    local tag="${4:-testing}"
    local images_file="${IMAGES_FILE:-${SCRIPT_DIR}/../images.yaml}"

    if [[ ! -f "$images_file" ]]; then
        echo "Error: Images file not found: $images_file" >&2
        return 1
    fi

    if ! command -v yq &> /dev/null; then
        echo "Error: yq is required but not installed" >&2
        return 1
    fi

    # Find the target index
    local targets_count=$(yq '.images.targets | length' "$images_file")
    local target_idx=-1

    for ((i=0; i<targets_count; i++)); do
        local target_name=$(yq ".images.targets[$i].name" "$images_file")
        if [[ "$target_name" == "$target" ]]; then
            target_idx=$i
            break
        fi
    done

    if [[ $target_idx -eq -1 ]]; then
        echo "Error: Target '$target' not found" >&2
        return 1
    fi

    local target_upstream=$(yq ".images.targets[$target_idx].upstream-image // \"\"" "$images_file")
    local target_tags_count=$(yq ".images.targets[$target_idx].tags | length" "$images_file" 2>/dev/null || echo "0")

    local found=false

    # Case 1: No variant specified (target only)
    if [[ -z "$variant" ]]; then
        # Check if target has variants
        local variants_count=$(yq ".images.targets[$target_idx].variants | length" "$images_file" 2>/dev/null || echo "0")

        if [[ "$variants_count" -eq 0 ]]; then
            # Output target-level descriptor
            for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
                local tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$images_file")

                # Skip if tag doesn't match
                [[ "$tag_name" != "$tag" ]] && continue

                local upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$images_file")

                found=true
                cat <<EOF
{
  "target": "$target",
  "variant": null,
  "configuration": null,
  "image_name": "$target",
  "upstream_image": "$target_upstream",
  "tag": "$tag_name",
  "upstream_tag": "$upstream_tag"
}
EOF
                break
            done
        else
            echo "Error: Target '$target' has variants. Please specify a variant." >&2
            return 1
        fi
    else
        # Case 2: Variant specified
        local variants_count=$(yq ".images.targets[$target_idx].variants | length" "$images_file" 2>/dev/null || echo "0")
        local variant_idx=-1

        for ((i=0; i<variants_count; i++)); do
            local variant_name=$(yq ".images.targets[$target_idx].variants[$i].name" "$images_file")
            if [[ "$variant_name" == "$variant" ]]; then
                variant_idx=$i
                break
            fi
        done

        if [[ $variant_idx -eq -1 ]]; then
            echo "Error: Variant '$variant' not found for target '$target'" >&2
            echo "]"
            return 1
        fi

        local variant_upstream=$(yq ".images.targets[$target_idx].variants[$variant_idx].upstream-image // \"$target_upstream\"" "$images_file")

        # Case 2a: No configuration specified (variant only)
        if [[ -z "$configuration" ]]; then
            # Output variant-level descriptor (without configuration)
            if [[ -n "$variant_upstream" && "$variant_upstream" != "null" ]]; then
                for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
                    local tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$images_file")

                    # Skip if tag doesn't match
                    [[ "$tag_name" != "$tag" ]] && continue

                    local upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$images_file")

                    found=true
                    cat <<EOF
{
  "target": "$target",
  "variant": "$variant",
  "configuration": null,
  "image_name": "${target}-${variant}",
  "upstream_image": "$variant_upstream",
  "tag": "$tag_name",
  "upstream_tag": "$upstream_tag"
}
EOF
                    break
                done
            else
                echo "Error: Variant '$variant' requires a configuration" >&2
                return 1
            fi
        else
            # Case 2b: Configuration specified
            local configs_count=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations | length" "$images_file" 2>/dev/null || echo "0")
            local config_idx=-1

            for ((i=0; i<configs_count; i++)); do
                local config_name=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$i].name" "$images_file")
                if [[ "$config_name" == "$configuration" ]]; then
                    config_idx=$i
                    break
                fi
            done

            if [[ $config_idx -eq -1 ]]; then
                echo "Error: Configuration '$configuration' not found for variant '$variant'" >&2
                echo "]"
                return 1
            fi

            local config_upstream=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].upstream-image // \"$variant_upstream\"" "$images_file")
            local config_tags_count=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags | length" "$images_file" 2>/dev/null || echo "0")

            if [[ "$config_tags_count" -gt 0 ]]; then
                # Use configuration-specific tags
                for ((tag_idx=0; tag_idx<config_tags_count; tag_idx++)); do
                    local tag_name=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags[$tag_idx].name" "$images_file")

                    # Skip if tag doesn't match
                    [[ "$tag_name" != "$tag" ]] && continue

                    local upstream_tag=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$images_file")

                    found=true
                    cat <<EOF
{
  "target": "$target",
  "variant": "$variant",
  "configuration": "$configuration",
  "image_name": "${target}-${variant}-${configuration}",
  "upstream_image": "$config_upstream",
  "tag": "$tag_name",
  "upstream_tag": "$upstream_tag"
}
EOF
                    break
                done
            else
                # Use target-level tags
                for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
                    local tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$images_file")

                    # Skip if tag doesn't match
                    [[ "$tag_name" != "$tag" ]] && continue

                    local upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$images_file")

                    found=true
                    cat <<EOF
{
  "target": "$target",
  "variant": "$variant",
  "configuration": "$configuration",
  "image_name": "${target}-${variant}-${configuration}",
  "upstream_image": "$config_upstream",
  "tag": "$tag_name",
  "upstream_tag": "$upstream_tag"
}
EOF
                    break
                done
            fi
        fi
    fi

    if [[ "$found" == "false" ]]; then
        echo "Error: Tag '$tag' not found for the specified combination" >&2
        return 1
    fi
}

# Main execution (only runs when script is executed directly, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

set -euo pipefail

IMAGES_FILE="${1:-${SCRIPT_DIR}/../images.yaml}"

if [[ ! -f "$IMAGES_FILE" ]]; then
    echo "Error: Images file not found: $IMAGES_FILE" >&2
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed" >&2
    exit 1
fi

# Output format: JSON array of image descriptors
# Each descriptor has:
#   - target: base target name (server, desktop, gaming)
#   - variant: variant name (optional)
#   - configuration: configuration name (optional)
#   - image_name: computed full name (target[-variant][-configuration])
#   - upstream_image: the upstream image to build from
#   - tag: local tag name
#   - upstream_tag: upstream tag name

echo "["

first_descriptor=true

# Iterate through each target
targets_count=$(yq '.images.targets | length' "$IMAGES_FILE")
for ((target_idx=0; target_idx<targets_count; target_idx++)); do
    target_name=$(yq ".images.targets[$target_idx].name" "$IMAGES_FILE")
    target_upstream=$(yq ".images.targets[$target_idx].upstream-image // \"\"" "$IMAGES_FILE")

    # Get target-level tags
    target_tags_count=$(yq ".images.targets[$target_idx].tags | length" "$IMAGES_FILE" 2>/dev/null || echo "0")

    # Check if target has variants
    variants_count=$(yq ".images.targets[$target_idx].variants | length" "$IMAGES_FILE" 2>/dev/null || echo "0")

    if [[ "$variants_count" -eq 0 ]]; then
        # No variants - process target directly with its tags
        for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
            tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$IMAGES_FILE")
            upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$IMAGES_FILE")

            [[ "$first_descriptor" == "false" ]] && echo ","
            first_descriptor=false

            cat <<EOF
  {
    "target": "$target_name",
    "variant": null,
    "configuration": null,
    "image_name": "$target_name",
    "upstream_image": "$target_upstream",
    "tag": "$tag_name",
    "upstream_tag": "$upstream_tag"
  }
EOF
        done
    else
        # Process each variant
        for ((variant_idx=0; variant_idx<variants_count; variant_idx++)); do
            variant_name=$(yq ".images.targets[$target_idx].variants[$variant_idx].name" "$IMAGES_FILE")
            variant_upstream=$(yq ".images.targets[$target_idx].variants[$variant_idx].upstream-image // \"$target_upstream\"" "$IMAGES_FILE")

            # Check if variant has configurations
            configs_count=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations | length" "$IMAGES_FILE" 2>/dev/null || echo "0")

            # Output base variant (unless it has no upstream image, which means it only exists as configurations)
            if [[ -n "$variant_upstream" && "$variant_upstream" != "null" ]]; then
                for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
                    tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$IMAGES_FILE")
                    upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$IMAGES_FILE")

                    [[ "$first_descriptor" == "false" ]] && echo ","
                    first_descriptor=false

                    cat <<EOF
  {
    "target": "$target_name",
    "variant": "$variant_name",
    "configuration": null,
    "image_name": "${target_name}-${variant_name}",
    "upstream_image": "$variant_upstream",
    "tag": "$tag_name",
    "upstream_tag": "$upstream_tag"
  }
EOF
                done
            fi

            if [[ "$configs_count" -gt 0 ]]; then
                # Process each configuration
                for ((config_idx=0; config_idx<configs_count; config_idx++)); do
                    config_name=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].name" "$IMAGES_FILE")
                    config_upstream=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].upstream-image // \"$variant_upstream\"" "$IMAGES_FILE")

                    # Check if configuration has custom tags
                    config_tags_count=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags | length" "$IMAGES_FILE" 2>/dev/null || echo "0")

                    if [[ "$config_tags_count" -gt 0 ]]; then
                        # Use configuration-specific tags
                        for ((tag_idx=0; tag_idx<config_tags_count; tag_idx++)); do
                            tag_name=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags[$tag_idx].name" "$IMAGES_FILE")
                            upstream_tag=$(yq ".images.targets[$target_idx].variants[$variant_idx].configurations[$config_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$IMAGES_FILE")

                            [[ "$first_descriptor" == "false" ]] && echo ","
                            first_descriptor=false

                            cat <<EOF
  {
    "target": "$target_name",
    "variant": "$variant_name",
    "configuration": "$config_name",
    "image_name": "${target_name}-${variant_name}-${config_name}",
    "upstream_image": "$config_upstream",
    "tag": "$tag_name",
    "upstream_tag": "$upstream_tag"
  }
EOF
                        done
                    else
                        # Use target-level tags
                        for ((tag_idx=0; tag_idx<target_tags_count; tag_idx++)); do
                            tag_name=$(yq ".images.targets[$target_idx].tags[$tag_idx].name" "$IMAGES_FILE")
                            upstream_tag=$(yq ".images.targets[$target_idx].tags[$tag_idx].upstream-name // \"$tag_name\"" "$IMAGES_FILE")

                            [[ "$first_descriptor" == "false" ]] && echo ","
                            first_descriptor=false

                            cat <<EOF
  {
    "target": "$target_name",
    "variant": "$variant_name",
    "configuration": "$config_name",
    "image_name": "${target_name}-${variant_name}-${config_name}",
    "upstream_image": "$config_upstream",
    "tag": "$tag_name",
    "upstream_tag": "$upstream_tag"
  }
EOF
                        done
                    fi
                done
            fi
        done
    fi
done

echo ""
echo "]"

fi  # End of main execution block
