# Stage 1: Compile dynamically on Alpine 3.24
FROM alpine:3.24 AS builder

RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    linux-headers \
    ninja \
    boost-dev \
    openssl-dev \
    qt6-qtbase-dev \
    qt6-qtbase-private-dev \
    qt6-qttools-dev \
    zlib-dev

WORKDIR /build

# 1. Clone & compile your libtorrent fork statically
RUN git clone --branch RC_2_0_leecher --single-branch --recurse-submodules https://github.com/Razor221/libtorrent.git \
    && cd libtorrent \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_CXX_FLAGS="-march=native" \
    && cmake --build build -j$(nproc) \
    && cmake --install build

# 2. Clone & compile qBittorrent release-5.2.4 in headless mode (Dynamic linking)
RUN git clone --branch release-5.2.4 --single-branch https://github.com/qbittorrent/qBittorrent.git \
    && cd qBittorrent \
    && cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_CXX_FLAGS="-march=native" \
        -DGUI=OFF \
    && cmake --build build -j$(nproc) \
    && cmake --install build \
    && strip --strip-all /usr/local/bin/qbittorrent-nox

# Stage 2: Inject into LinuxServer's official container
FROM lscr.io/linuxserver/qbittorrent:latest

# Install the exact Qt6 runtime shared libraries that caused your symbol errors
RUN apk add --no-cache \
    qt6-qtbase \
    qt6-qtbase-sqlite

# Overwrite LinuxServer's stock executable with your compiled binary
COPY --from=builder /usr/local/bin/qbittorrent-nox /app/qbittorrent-nox