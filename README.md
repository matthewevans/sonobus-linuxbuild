# SonoBus Linux Build

Builds and packages [SonoBus](https://sonobus.net) for Linux (`.deb` and `.rpm`), and publishes an apt repository at [pkg.sonobus.net](https://pkg.sonobus.net).

## How it works

1. **`scripts/build.sh`** — Builds SonoBus in Docker (cross-arch via QEMU), then packages with [fpm](https://fpm.readthedocs.io/)
2. **`scripts/update-repo.sh`** — Generates apt repo metadata and pushes to [sonobus-packages](https://github.com/sonosaurus/sonobus-packages)
3. **GitHub Actions** — Primary build path. Trigger manually or push a `v*` tag to build + publish

## GitHub Actions (primary)

Trigger a build from the Actions tab, or from CLI:

```sh
# Build only (no publish)
gh workflow run build.yml -f branch=main

# Build and publish to apt repo
gh workflow run build.yml -f branch=main -f publish=true
```

### Required secrets

| Secret | Description |
|--------|-------------|
| `PACKAGES_DEPLOY_TOKEN` | GitHub PAT with write access to `sonosaurus/sonobus-packages` |
| `GPG_PRIVATE_KEY` | (Optional) GPG private key for signing the apt repo |
| `GPG_KEY_ID` | (Optional) GPG key email/ID |

## Local builds (for testing)

Requires Docker with buildx.

```sh
# One-time setup for cross-platform builds
make setup

# Build a single target
make build DISTRO=debian ARCH=amd64

# Build all Debian architectures
make build-all-deb

# Clean artifacts
make clean
```

## Structure

```
├── config.env                  # Package metadata and settings
├── Makefile                    # Local build convenience targets
├── docker/
│   ├── Dockerfile.build-deb    # Debian/Ubuntu build environment
│   ├── Dockerfile.build-rpm    # CentOS/Fedora build environment
│   ├── Dockerfile.fpm-deb      # FPM for .deb packaging
│   ├── Dockerfile.fpm-rpm      # FPM for .rpm packaging
│   └── Dockerfile.sonobus      # SonoBus compilation stage
├── scripts/
│   ├── build.sh                # Build + package (single target)
│   └── update-repo.sh          # Update apt repository
└── .github/workflows/
    └── build.yml               # CI/CD pipeline
```

## Adding a user's apt repository

```sh
curl -fsSL https://pkg.sonobus.net/apt/keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/sonobus.gpg
echo "deb [signed-by=/usr/share/keyrings/sonobus.gpg] https://pkg.sonobus.net/apt stable main" | sudo tee /etc/apt/sources.list.d/sonobus.list
sudo apt update && sudo apt install sonobus
```
