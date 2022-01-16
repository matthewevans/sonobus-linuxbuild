#!/bin/bash

set -x

# Build FPM in local docker registry
docker buildx build --network=host \
	            --platform ${PLATFORM} \
	            -t ${FPM_TAG} \
		    --cache-from=type=registry,ref=${FPM_CACHE_TAG} \
                    --cache-to=type=registry,ref=${FPM_CACHE_TAG},mode=max \
		    --build-arg imagename=${DISTRO_IMAGE_NAME} \
		    -f ../Dockerfile.fpm_${PACKAGE} \
		    --push \
		    . || exit 1 

# Build base OS image (with CMake) in local docker registry
docker buildx build --network=host \
	            --platform ${PLATFORM} \
		    -t ${BASE_TAG} \
		    --cache-from=type=registry,ref=${BASE_CACHE_TAG} \
                    --cache-to=type=registry,ref=${BASE_CACHE_TAG},mode=max \
		    --build-arg imagename=${DISTRO_IMAGE_NAME} \
		    -f Dockerfile.base \
		    --push \
		    . || exit 1 

# Build SonoBus from custom OS image (from local docker registry)
docker buildx build --no-cache \
	            --network=host \
		    --platform ${PLATFORM} \
		    -t ${SONOBUS_NAME} \
		    --build-arg branch=${COMPONENT} \
		    --build-arg imagename="${BASE_TAG}" \
		    --load \
		    . || exit 1

