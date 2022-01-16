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
EXENAME="$( basename "$SOURCE" )"
EXELOC="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd "$EXELOC"

DISTRO=centos
VERSION=8
PACKAGE=rpm
FPM_OPTS="-d opus -d jack-audio-connection-kit -d alsa-lib -d libX11 -d libXext -d libXinerama -d libXrandr -d libXcursor -d freetype -d libcurl"
#FPM_OPTS="-d opus -d jack-audio-connection-kit -d alsa-lib -d libX11 -d libXext -d libXinerama -d libXrandr -d libXcursor -d mesa-libGL -d freetype -d libcurl"

PLATFORM=amd64
cd "$LOCALEXELOC"
. ../run.sh "$@"

