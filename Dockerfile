# Stage 1: Compile on Alpine 3.24
FROM alpine:3.24 AS builder

RUN apk add --no-cache \
    build-base \
    cmake \
    curl \
    git \
    linux-headers \
    ninja \
    openssl-dev \
    qt6-qtbase-dev \
    qt6-qtbase-private-dev \
    qt6-qttools-dev \
    zlib-dev

WORKDIR /build

# 1. Download and copy Boost 1.92.0 headers directly into /usr/local/include
RUN curl -fLO https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-b2-nodocs.tar.gz \
    && tar -xzf boost-1.92.0-b2-nodocs.tar.gz \
    && mkdir -p /usr/local/include \
    && cp -r boost-1.92.0/boost /usr/local/include/ \
    && rm -rf boost-1.92.0*

# 2. Clone & compile your libtorrent fork statically against Boost 1.92.0
RUN git clone --recurse-submodules https://github.com/Razor221/libtorrent.git \
    && cd libtorrent \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=OFF \
    && cmake --build build -j$(nproc) \
    && cmake --install build \
    && cd .. \
    && rm -rf libtorrent

# 3. Clone & compile qBittorrent release-5.3.0 in headless mode
RUN git clone --branch release-5.3.0 --single-branch https://github.com/qbittorrent/qBittorrent.git \
    && cd qBittorrent \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DGUI=OFF \
    && cmake --build build -j$(nproc) \
    && cmake --install build \
    && cd .. \
    && rm -rf qBittorrent


# Stage 2: Inject into LinuxServer's official container
FROM lscr.io/linuxserver/qbittorrent:latest

# Install required Qt6 runtime shared libraries to satisfy dynamic symbols
RUN apk add --no-cache \
    qt6-qtbase \
    qt6-qtbase-sqlite

# Overwrite LinuxServer's stock executable with your compiled binary
COPY --from=builder /usr/local/bin/qbittorrent-nox /app/qbittorrent-nox
