# SonoBus Linux Build System
# ==========================
#
# Local usage (for testing):
#   make build DISTRO=debian ARCH=amd64
#   make build-all-deb
#   make clean
#
# Primary builds happen in GitHub Actions (see .github/workflows/build.yml).
# Use `gh workflow run build.yml` to trigger a build from your terminal.

DISTRO     ?= debian
ARCH       ?= amd64
BRANCH     ?= main
BASE_IMAGE ?=
ITERATION  ?= 0

DEB_ARCHS  := amd64 arm64 i386 armhf

.PHONY: build build-all-deb clean setup trigger

build: ## Build + package one target
	./scripts/build.sh --distro $(DISTRO) --arch $(ARCH) --branch $(BRANCH) \
		--iteration $(ITERATION) $(if $(BASE_IMAGE),--base-image $(BASE_IMAGE))

build-all-deb: ## Build + package all Debian architectures
	@for arch in $(DEB_ARCHS); do \
		$(MAKE) build DISTRO=debian ARCH=$$arch BRANCH=$(BRANCH) || exit 1; \
	done

clean: ## Remove build artifacts
	rm -rf dist/ output/

setup: ## Set up Docker buildx for cross-platform builds
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	-docker buildx create --name sonobus --use --driver docker-container
	docker buildx inspect --bootstrap

trigger: ## Trigger a GHA build (requires gh CLI)
	gh workflow run build.yml -f branch=$(BRANCH) -f iteration=$(ITERATION) -f publish=false
