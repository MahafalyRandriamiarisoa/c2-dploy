# syntax=docker/dockerfile:1.4

# ============================================================================
# Stage 1: Builder - Compilation de Havoc pour Linux
# ============================================================================
FROM golang:1.21-bullseye AS builder

LABEL stage="havoc-builder"

# Installation des dépendances de compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    libfontconfig1 \
    libglu1-mesa-dev \
    libgtest-dev \
    libspdlog-dev \
    libboost-all-dev \
    libncurses5-dev \
    libgdbm-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    mesa-common-dev \
    nasm \
    make \
    mingw-w64 \
    python3-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Variables d'environnement pour la compilation
ENV GOOS=linux
ENV GOARCH=amd64
ENV CGO_ENABLED=1

WORKDIR /build

# Clone et compilation du teamserver Havoc
RUN git config --global http.sslverify false && \
    git clone --depth 1 https://github.com/HavocFramework/Havoc.git . && \
    cd teamserver && \
    go mod download && \
    go build -buildmode=exe -ldflags "-s -w" -o ../havoc .

# ============================================================================
# Stage 2: Runtime - Image finale minimale
# ============================================================================
FROM ubuntu:22.04 AS runtime

LABEL maintainer="C2-Dploy"
LABEL description="Havoc C2 Framework – teamserver optimisé multi-stage"

# Runtime packages légers + compilateurs mingw pour les payloads
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    curl \
    netcat \
    mingw-w64 \
    nasm \
    && rm -rf /var/lib/apt/lists/*

# Copie du binaire compilé depuis le stage builder
COPY --from=builder /build/havoc /usr/local/bin/havoc
COPY --from=builder /build/havoc /opt/havoc/havoc
COPY --from=builder /build/profiles /opt/havoc/profiles

# Créer le répertoire data montable depuis l'hôte
RUN mkdir -p /opt/havoc/data

# Variables d'environnement
ENV HAVOC_PATH=/opt/havoc
ENV PATH="/usr/local/bin:$PATH"

# Ports par défaut du teamserver
EXPOSE 40056 443

# Script de démarrage
COPY start-havoc.sh /start-havoc.sh
RUN chmod +x /start-havoc.sh

# Health check optimisé (test TCP sur le port du teamserver)
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD nc -z localhost 40056 || exit 1

CMD ["/start-havoc.sh"] 