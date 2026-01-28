# This image is based on a Unversal Blue base image (ghcr.io/ublue-os/<BASE_IMAGE>:<TAG_VERSION>)
ARG UPSTREAM_IMAGE="ucore-hci"
ARG UPSTREAM_TAG="stable"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files/
COPY system_files /system_files/

# Base Image
FROM ${UPSTREAM_IMAGE}:${UPSTREAM_TAG}

ARG TARGET_NAME "server"
ARG VARIANT_NAME "hci"
ARG CONFIGURATION_NAME "nvidia"
ARG TARGET_TAG "stable"

ARG SET_X=""
ARG VERSION=""
ARG DNF="dnf5"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

### LINTING
## Verify final image and contents are correct.
## (this also causes a commit of the ostree container if applicable)
RUN bootc container lint
