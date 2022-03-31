#!/bin/bash

set -x

/bin/rm -rf ./dist

docker container create --platform ${PLATFORM} --name temp ${SONOBUS_NAME}
docker container cp temp:/dist ./dist
docker container rm temp

tree ./dist

if [ ! -f ./dist/usr/share/applications/sonobus.desktop ]; then
	echo "sonobus.desktop file not found.. Failed to copy all files"
	exit 1
fi

echo "Removing Sonobus build image"
docker image rm ${SONOBUS_NAME}

ITER_VER=0
BUILD=`curl -s https://raw.githubusercontent.com/sonosaurus/sonobus/${COMPONENT}/CMakeLists.txt | grep -oE "^project\(SonoBus VERSION ([0-9]+\.[0-9]+\.[0-9]+)" | sort -u | awk -F' ' '{print $NF}'`

docker run --platform ${PLATFORM} --rm -it -w "/src/" -v "${PWD}/dist:/src/" ${FPM_TAG} \
	fpm \
	-s dir \
	-f \
	-t ${PACKAGE} \
	-n sonobus \
	-p sonobus_VERSION_${DISTRO}_ARCH.${PACKAGE} \
	-v ${BUILD}-${ITER_VER} \
	--url "https://www.sonobus.net" \
	--license "GPL-3.0" \
	--category music \
	--maintainer "Matt Evans" \
	--description "SonoBus is an easy to use application for streaming high-quality, low-latency peer-to-peer audio between devices over the internet or a local network.\n\nSimply choose a unique group name (with optional password), and instantly connect multiple people together to make music, remote sessions, podcasts, etc. Easily record the audio from everyone, as well as playback any audio content to the whole group. Connects multiple users together to send and receive audio among all in a group, with fine-grained control over latency, quality and overall mix. Includes optional input compression, noise gate, and EQ effects, along with a master reverb. All settings are dynamic, network statistics are clearly visible." \
	${FPM_OPTS} \
	usr

if [[ ! -z $(ls ./dist/*.deb 2>/dev/null) ]]
then
	echo "Adding deb to freight"
	cd $EXELOC
	freight add -v -c ./freight.conf ./debian/dist/*.deb apt/stable/main
fi

#freight cache -v -c $EXECLOC/freight.conf apt/stable

