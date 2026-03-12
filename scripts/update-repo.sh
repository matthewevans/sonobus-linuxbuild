#!/usr/bin/env bash
#
# Update the sonobus-packages apt repository with .deb files from output/.
# Designed to run in CI (requires dpkg-scanpackages).
#
# Usage: ./scripts/update-repo.sh [--repo-dir DIR] [--push]
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/config.env"

OUTPUT_DIR="$ROOT_DIR/output"
REPO_DIR=""
PUSH=false
CLEANUP=false

die() { echo "Error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-dir) REPO_DIR="$2"; shift 2 ;;
        --push)     PUSH=true;     shift ;;
        -h|--help)
            echo "Usage: update-repo.sh [--repo-dir DIR] [--push]"
            exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

command -v dpkg-scanpackages >/dev/null 2>&1 || die "dpkg-scanpackages not found (install dpkg-dev)"

shopt -s nullglob
DEBS=("$OUTPUT_DIR"/*.deb)
shopt -u nullglob
[[ ${#DEBS[@]} -eq 0 ]] && die "No .deb files in $OUTPUT_DIR"

echo "==> Packages to add:"
printf '    %s\n' "${DEBS[@]##*/}"

# Get or clone the packages repo
if [[ -z "$REPO_DIR" ]]; then
    REPO_DIR=$(mktemp -d)
    CLEANUP=true
    echo "==> Cloning ${PACKAGES_REPO}"
    git clone --depth 1 --branch gh-pages "https://github.com/${PACKAGES_REPO}.git" "$REPO_DIR"
fi

POOL="$REPO_DIR/apt/pool/stable/main/s/sonobus"
DISTS="$REPO_DIR/apt/dists/stable"
mkdir -p "$POOL"

cp -v "${DEBS[@]}" "$POOL/"

# Detect architectures from the .deb filenames
ARCHS=$(for f in "${DEBS[@]}"; do basename "$f"; done | grep -oE '(amd64|arm64|armhf|i386)' | sort -u)

echo "==> Generating metadata for: ${ARCHS}"
for arch in $ARCHS; do
    BDIR="$DISTS/main/binary-${arch}"
    mkdir -p "$BDIR"

    (cd "$REPO_DIR/apt" && dpkg-scanpackages --arch "$arch" pool/) > "$BDIR/Packages"
    gzip -9fk "$BDIR/Packages"

    cat > "$BDIR/Release" <<EOF
Archive: stable
Component: main
Origin: ${APT_ORIGIN}
Label: ${APT_LABEL}
Architecture: ${arch}
EOF
done

# Generate top-level Release
ALL_ARCHS=$(find "$DISTS/main" -mindepth 1 -maxdepth 1 -type d -name 'binary-*' \
    | sed 's|.*/binary-||' | sort | tr '\n' ' ')

generate_hashes() {
    local algo="$1" cmd="$2"
    echo "${algo}:"
    (cd "$DISTS" && find main -type f \( -name 'Packages' -o -name 'Packages.gz' -o -name 'Release' \) | sort | while read -r f; do
        local hash size
        hash=$($cmd "$f" | awk '{print $1}')
        size=$(wc -c < "$f" | tr -d ' ')
        printf " %s %16s %s\n" "$hash" "$size" "$f"
    done)
}

{
    echo "Origin: ${APT_ORIGIN}"
    echo "Label: ${APT_LABEL}"
    echo "Suite: stable"
    echo "Codename: stable"
    echo "Architectures: ${ALL_ARCHS}"
    echo "Components: main"
    echo "Date: $(date -Ru 2>/dev/null || date -u '+%a, %d %b %Y %H:%M:%S %z')"
    generate_hashes "MD5Sum" "md5sum"
    generate_hashes "SHA256" "sha256sum"
} > "$DISTS/Release"

# GPG signing
if [[ -n "${APT_GPG_KEY:-}" ]]; then
    echo "==> Signing with GPG key: ${APT_GPG_KEY}"
    gpg --batch --yes --default-key "$APT_GPG_KEY" -abs -o "$DISTS/Release.gpg" "$DISTS/Release"
    gpg --batch --yes --default-key "$APT_GPG_KEY" --clearsign -o "$DISTS/InRelease" "$DISTS/Release"
    gpg --armor --export "$APT_GPG_KEY" > "$REPO_DIR/apt/keyring.gpg"
fi

if $PUSH; then
    echo "==> Pushing to ${PACKAGES_REPO}"
    cd "$REPO_DIR"
    git add -A
    git diff --cached --quiet && { echo "No changes"; exit 0; }
    git commit -m "Update packages $(date -u +%Y-%m-%d)"
    git push
    $CLEANUP && rm -rf "$REPO_DIR"
else
    echo "==> Repository updated locally at: $REPO_DIR/apt"
    echo "    Use --push to publish"
fi
