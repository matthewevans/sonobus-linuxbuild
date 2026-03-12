#!/usr/bin/env bash
#
# Build and package SonoBus for a target distro/arch.
#
# Usage:
#   ./scripts/build.sh --distro debian --arch amd64
#   ./scripts/build.sh --distro debian --arch arm64 --base-image ubuntu:focal
#   ./scripts/build.sh --distro centos --arch amd64
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/config.env"

DISTRO=""
ARCH=""
BRANCH="${SONOBUS_BRANCH}"
BASE_IMAGE=""
ITERATION="0"

die()   { echo "Error: $*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: build.sh --distro DISTRO --arch ARCH [OPTIONS]

Options:
    --distro      debian|ubuntu|centos|fedora  (required)
    --arch        amd64|arm64|i386|armhf       (required)
    --branch      SonoBus git branch           (default: main)
    --base-image  Override base Docker image
    --iteration   Package revision number      (default: 0)
    -h, --help    Show this help
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)     DISTRO="$2";     shift 2 ;;
        --arch)       ARCH="$2";       shift 2 ;;
        --branch)     BRANCH="$2";     shift 2 ;;
        --base-image) BASE_IMAGE="$2"; shift 2 ;;
        --iteration)  ITERATION="$2";  shift 2 ;;
        -h|--help)    usage ;;
        *)            die "Unknown option: $1" ;;
    esac
done

[[ -z "$DISTRO" ]] && die "--distro is required"
[[ -z "$ARCH" ]]   && die "--arch is required"

# Resolve distro family
case "$DISTRO" in
    debian|ubuntu)
        PKG_TYPE="deb"
        BASE_IMAGE="${BASE_IMAGE:-ubuntu:jammy}"
        DOCKERFILE_BUILD="$ROOT_DIR/docker/Dockerfile.build-deb"
        DOCKERFILE_FPM="$ROOT_DIR/docker/Dockerfile.fpm-deb"
        FPM_DEPS="-d libjack-jackd2-0|libjack0 -d libopus0 -d libasound2 -d libx11-6 -d libxext6 -d libxinerama1 -d libxrandr2 -d libxcursor1 -d libfreetype6 -d libcurl4"
        ;;
    centos|rhel|fedora)
        PKG_TYPE="rpm"
        BASE_IMAGE="${BASE_IMAGE:-centos:8}"
        DOCKERFILE_BUILD="$ROOT_DIR/docker/Dockerfile.build-rpm"
        DOCKERFILE_FPM="$ROOT_DIR/docker/Dockerfile.fpm-rpm"
        FPM_DEPS="-d opus -d jack-audio-connection-kit -d alsa-lib -d libX11 -d libXext -d libXinerama -d libXrandr -d libXcursor -d freetype -d libcurl"
        ;;
    *) die "Unknown distro '$DISTRO'" ;;
esac

# Map Debian arch names to Docker platform strings
case "$ARCH" in
    amd64) PLATFORM="linux/amd64" ;;
    arm64) PLATFORM="linux/arm64" ;;
    armhf) PLATFORM="linux/arm/v7" ;;
    i386)  PLATFORM="linux/386" ;;
    *)     die "Unknown architecture '$ARCH'" ;;
esac
TAG="${DISTRO}-${ARCH}"
BUILD_ENV_TAG="sonobus-build-env:${TAG}"
BUILD_TAG="sonobus-build:${TAG}"
FPM_TAG="sonobus-fpm:${TAG}"
DIST_DIR="$ROOT_DIR/dist/${TAG}"
OUTPUT_DIR="$ROOT_DIR/output"

# --- Step 1: Build environment image ---
echo "==> [1/5] Building build environment (${BUILD_ENV_TAG})"
docker buildx build \
    --platform "$PLATFORM" \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "CMAKE_VERSION=${CMAKE_VERSION}" \
    -t "$BUILD_ENV_TAG" \
    --load \
    -f "$DOCKERFILE_BUILD" \
    "$ROOT_DIR/docker"

# --- Step 2: Build SonoBus ---
echo "==> [2/5] Building SonoBus (branch: ${BRANCH})"
docker buildx build \
    --no-cache \
    --platform "$PLATFORM" \
    --build-arg "BUILD_IMAGE=${BUILD_ENV_TAG}" \
    --build-arg "BRANCH=${BRANCH}" \
    -t "$BUILD_TAG" \
    --load \
    -f "$ROOT_DIR/docker/Dockerfile.sonobus" \
    "$ROOT_DIR/docker"

# --- Step 3: Extract artifacts ---
echo "==> [3/5] Extracting build artifacts"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

CID=$(docker container create --platform "$PLATFORM" "$BUILD_TAG")
docker container cp "$CID:/dist/." "$DIST_DIR/"
docker container rm "$CID" > /dev/null
docker image rm "$BUILD_TAG" > /dev/null 2>&1 || true

[[ -f "$DIST_DIR/usr/bin/sonobus" ]] || die "Build failed — sonobus binary not found"

# --- Step 4: Get version ---
echo "==> [4/5] Resolving version"
VERSION=$(curl -sf "https://raw.githubusercontent.com/sonosaurus/sonobus/${BRANCH}/CMakeLists.txt" \
    | grep -oE '^project\(SonoBus VERSION [0-9]+\.[0-9]+\.[0-9]+' \
    | awk '{print $NF}') || true
[[ -z "$VERSION" ]] && die "Could not determine SonoBus version"
echo "    ${PKG_NAME} ${VERSION}-${ITERATION} (${PKG_TYPE})"

# --- Step 5: Package with fpm ---
echo "==> [5/5] Packaging ${PKG_NAME}_${VERSION}-${ITERATION}_${TAG}.${PKG_TYPE}"
docker buildx build \
    --platform "$PLATFORM" \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    -t "$FPM_TAG" \
    --load \
    -f "$DOCKERFILE_FPM" \
    "$ROOT_DIR/docker"

mkdir -p "$OUTPUT_DIR"

# shellcheck disable=SC2086
docker run --rm \
    --platform "$PLATFORM" \
    -v "${DIST_DIR}:/src:ro" \
    -v "${OUTPUT_DIR}:/output" \
    -w /src \
    "$FPM_TAG" \
    fpm -s dir -f -t "$PKG_TYPE" \
        -n "$PKG_NAME" \
        -p "/output/${PKG_NAME}_${VERSION}-${ITERATION}_${TAG}.${PKG_TYPE}" \
        -v "${VERSION}-${ITERATION}" \
        --url "$PKG_URL" \
        --license "$PKG_LICENSE" \
        --category "$PKG_CATEGORY" \
        --maintainer "$PKG_MAINTAINER" \
        --description "$PKG_DESCRIPTION" \
        $FPM_DEPS \
        usr

echo ""
echo "==> Done! Package:"
ls -lh "$OUTPUT_DIR/${PKG_NAME}_${VERSION}-${ITERATION}_${TAG}.${PKG_TYPE}"
