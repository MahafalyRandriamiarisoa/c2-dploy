# syntax=docker/dockerfile:1.4

FROM ubuntu:22.04

LABEL maintainer="C2-Dploy"
LABEL description="Havoc C2 Framework – teamserver runtime image (pré-compilé)"

# Runtime packages légers (openssl pour HTTPS, ca-certificates pour TLS)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copie du binaire (compilé en dehors du Docker build) et des profils
COPY bin/havoc /usr/local/bin/havoc
COPY bin/havoc /opt/havoc/havoc
COPY profiles /opt/havoc/profiles

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

CMD ["/start-havoc.sh"] 