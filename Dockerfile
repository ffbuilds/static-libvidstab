
# bump: vid.stab /VIDSTAB_VERSION=([\d.]+)/ https://github.com/georgmartius/vid.stab.git|*
# bump: vid.stab after ./hashupdate Dockerfile VIDSTAB $LATEST
# bump: vid.stab link "Changelog" https://github.com/georgmartius/vid.stab/blob/master/Changelog
ARG VIDSTAB_VERSION=1.1.0
ARG VIDSTAB_URL="https://github.com/georgmartius/vid.stab/archive/v$VIDSTAB_VERSION.tar.gz"
ARG VIDSTAB_SHA256=14d2a053e56edad4f397be0cb3ef8eb1ec3150404ce99a426c4eb641861dc0bb

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG VIDSTAB_URL
ARG VIDSTAB_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O vid.stab.tar.gz "$VIDSTAB_URL" && \
  echo "$VIDSTAB_SHA256  vid.stab.tar.gz" | sha256sum --status -c - && \
  mkdir vidstab && \
  tar xf vid.stab.tar.gz -C vidstab --strip-components=1 && \
  rm vid.stab.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/vidstab/ /tmp/vidstab/
WORKDIR /tmp/vidstab/build
RUN \
  apk add --no-cache --virtual build \
    build-base cmake pkgconf && \
  sed -i 's/include (FindSSE)/if(CMAKE_SYSTEM_ARCH MATCHES "amd64")\ninclude (FindSSE)\nendif()/' ../CMakeLists.txt && \
  cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_SYSTEM_ARCH=$(arch) \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DUSE_OMP=ON \
    .. && \
  make -j$(nproc) install && \
  echo "Libs.private: -ldl" >> /usr/local/lib/pkgconfig/vidstab.pc && \
  # Sanity tests
  pkg-config --exists --modversion --path vidstab && \
  ar -t /usr/local/lib/libvidstab.a && \
  readelf -h /usr/local/lib/libvidstab.a && \
  # Cleanup
  apk del build

FROM scratch
ARG VIDSTAB_VERSION
COPY --from=build /usr/local/lib/pkgconfig/vidstab.pc /usr/local/lib/pkgconfig/vidstab.pc
COPY --from=build /usr/local/lib/libvidstab.a /usr/local/lib/libvidstab.a
COPY --from=build /usr/local/include/vid.stab/ /usr/local/include/vid.stab/
