#!/bin/bash

if [ -z "${DISTRO}" ]; then
	echo DISTRO not provided. Example values: ubuntu, debian, fedora, centos
	exit 1
fi

if [ -z "${VERSION}" ]; then
	echo VERSION not provided. Example values: 16.04, 18.04, 7, 24
	exit 1
fi

if [ -z "${PACKAGE}" ]; then
	echo PACKAGE not provided. Example values: deb, rpm
	exit 1
fi

if [ -z "${PLATFORM}" ]; then
	echo PLATFORM not provided. Example values: amd64, arm64, armhf
	exit 1
fi

