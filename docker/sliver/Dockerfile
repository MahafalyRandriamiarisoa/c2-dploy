# syntax=docker/dockerfile:1.4
FROM ubuntu:22.04

LABEL maintainer="C2-Dploy"
LABEL description="Sliver C2 Framework Container"

# Installation des dépendances
ARG DEBIAN_FRONTEND=noninteractive
# Installation standard sans cache BuildKit pour compatibilité Terraform
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    build-essential \
    mingw-w64 \
    binutils-mingw-w64 \
    g++-mingw-w64 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Installer Go
RUN curl -L https://go.dev/dl/go1.21.5.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV GOPROXY="direct"

# Installer Sliver manuellement (évite systemd)
ARG SLIVER_VERSION=1.5.43
RUN curl -L https://github.com/BishopFox/sliver/releases/download/v${SLIVER_VERSION}/sliver-server_linux -o /usr/local/bin/sliver-server && \
    curl -L https://github.com/BishopFox/sliver/releases/download/v${SLIVER_VERSION}/sliver-client_linux -o /usr/local/bin/sliver && \
    chmod +x /usr/local/bin/sliver /usr/local/bin/sliver-server

# Créer le répertoire de configuration
RUN mkdir -p /root/.sliver

# Exposer les ports
EXPOSE 31337 443

# Script de démarrage
COPY start-sliver.sh /start-sliver.sh
RUN chmod +x /start-sliver.sh

CMD ["/start-sliver.sh"] 