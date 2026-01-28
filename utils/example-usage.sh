#!/usr/bin/env bash
# Example script demonstrating how to source and use get_image_descriptor function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the flatten-images.sh script to import the function
source "${SCRIPT_DIR}/flatten-images.sh"

echo "Example 1: Get desktop developer variant (default tag: testing)"
echo "================================================================"
get_image_descriptor desktop developer | jq

echo -e "\nExample 2: Get desktop developer with stable tag"
echo "================================================="
get_image_descriptor desktop developer "" stable | jq

echo -e "\nExample 3: Get desktop developer nvidia configuration (testing tag)"
echo "===================================================================="
get_image_descriptor desktop developer nvidia testing | jq

echo -e "\nExample 4: Get desktop workstation with stable-daily tag"
echo "========================================================="
get_image_descriptor desktop workstation "" stable-daily | jq -c

echo -e "\nExample 5: Extract specific fields using jq"
echo "============================================"
echo "Stable image for desktop workstation:"
get_image_descriptor desktop workstation "" stable | jq -r '.image_name + ":" + .tag'

echo -e "\nExample 6: Get upstream image for gaming console nvidia (stable)"
echo "================================================================="
upstream=$(get_image_descriptor gaming console nvidia stable | jq -r '.upstream_image')
echo "Upstream image: $upstream"

echo -e "\nExample 7: Build command for server cloud stable"
echo "================================================="
get_image_descriptor server cloud "" stable | jq -r '"Building \(.image_name):\(.tag) from \(.upstream_image):\(.upstream_tag)"'
