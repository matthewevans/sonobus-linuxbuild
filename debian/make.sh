#!/bin/bash

ME=${0}
SOURCE="${BASH_SOURCE[0]}"
# resolve $SOURCE until the file is no longer a symlink
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
LOCALEXELOC="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


DISTRO=ubuntu
PACKAGE=deb
FPM_OPTS="-d libjack-jackd2-0|libjack0 -d libopus0 -d libasound2 -d libx11-6 -d libxext6 -d libxinerama1 -d libxrandr2 -d libxcursor1 -d libfreetype6 -d libcurl4"

VERSION=bionic

PLATFORM=amd64
cd "$LOCALEXELOC"
. ../run.sh "$@"

PLATFORM=386
cd "$LOCALEXELOC"
. ../run.sh "$@"

PLATFORM=arm64
cd "$LOCALEXELOC"
. ../run.sh "$@"

PLATFORM=armhf
cd "$LOCALEXELOC"
. ../run.sh "$@"

