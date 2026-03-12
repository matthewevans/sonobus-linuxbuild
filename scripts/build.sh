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

case "$DISTRO" in
    debian|ubuntu)
        BASE_IMAGE="${BASE_IMAGE:-ubuntu:jammy}"
        DOCKERFILE="$ROOT_DIR/docker/Dockerfile.deb"
        ;;
    centos|rhel|fedora)
        BASE_IMAGE="${BASE_IMAGE:-centos:8}"
        DOCKERFILE="$ROOT_DIR/docker/Dockerfile.rpm"
        ;;
    *) die "Unknown distro '$DISTRO'" ;;
esac

case "$ARCH" in
    amd64) PLATFORM="linux/amd64" ;;
    arm64) PLATFORM="linux/arm64" ;;
    armhf) PLATFORM="linux/arm/v7" ;;
    i386)  PLATFORM="linux/386" ;;
    *)     die "Unknown architecture '$ARCH'" ;;
esac

# Fetch upstream SHA to bust the sonobus stage cache only when source changes,
# while keeping the slow build-env (CMake compile) stage cached.
echo "==> Resolving upstream commit for branch '${BRANCH}'"
SONOBUS_SHA=$(git ls-remote "$SONOBUS_REPO" "refs/heads/${BRANCH}" 2>/dev/null | cut -f1 || echo "unknown")
echo "    SHA: ${SONOBUS_SHA}"

OUTPUT_DIR="$ROOT_DIR/output"
mkdir -p "$OUTPUT_DIR"

echo "==> Building ${DISTRO}/${ARCH}"
docker buildx build \
    --platform "$PLATFORM" \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "CMAKE_VERSION=${CMAKE_VERSION}" \
    --build-arg "BRANCH=${BRANCH}" \
    --build-arg "SONOBUS_SHA=${SONOBUS_SHA}" \
    --build-arg "ARCH=${ARCH}" \
    --build-arg "ITERATION=${ITERATION}" \
    --target export \
    --output "type=local,dest=${OUTPUT_DIR}" \
    -f "$DOCKERFILE" \
    "$ROOT_DIR/docker"

echo ""
echo "==> Done! Package:"
ls -lh "$OUTPUT_DIR"/*.deb "$OUTPUT_DIR"/*.rpm 2>/dev/null || true
