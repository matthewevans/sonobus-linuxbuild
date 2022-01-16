ARG imagename
ARG branch=main

FROM --platform=$TARGETPLATFORM ${imagename}

ARG branch

ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /dist/usr
RUN git clone -b ${branch} --single-branch https://github.com/sonosaurus/sonobus.git
WORKDIR sonobus/linux
#RUN sleep infinity
RUN set -x && ./build.sh && ./install.sh /dist/usr && strip --strip-unneeded /dist/usr/bin/sonobus

