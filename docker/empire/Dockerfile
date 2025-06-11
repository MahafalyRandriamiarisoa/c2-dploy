# syntax=docker/dockerfile:1.4
ARG DEBIAN_FRONTEND=noninteractive

FROM python:3.9-slim

LABEL maintainer="C2-Dploy"
LABEL description="Empire C2 Framework Container"

# Installation des dépendances avec cache BuildKit
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Cloner Empire
WORKDIR /opt
RUN git clone --recursive https://github.com/BC-SECURITY/Empire.git

WORKDIR /opt/Empire

# Installer Empire
RUN pip3 install -r requirements.txt
RUN python3 setup/install.py

# Créer le répertoire de données
RUN mkdir -p /opt/Empire/data

# Exposer les ports
EXPOSE 1337 5000

# Script de démarrage
COPY start-empire.sh /start-empire.sh
RUN chmod +x /start-empire.sh

CMD ["/start-empire.sh"] 