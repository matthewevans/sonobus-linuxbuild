ARG imagename
ARG branch=main

FROM --platform=$TARGETPLATFORM ${imagename}

ARG branch

RUN mkdir -p /dist/usr
RUN git clone -b ${branch} --single-branch https://github.com/sonosaurus/sonobus.git
RUN sed -i'' -E 's/set\(CMAKE_XCODE.*?$/\0\nSET(CMAKE_AR "gcc-ar")\nSET(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> qcs <TARGET> <LINK_FLAGS> <OBJECTS>")\nSET(CMAKE_CXX_ARCHIVE_FINISH true)/m' sonobus/CMakeLists.txt
WORKDIR sonobus/linux
RUN set -x && ./build.sh && ./install.sh /dist/usr && strip --strip-unneeded /dist/usr/bin/sonobus

