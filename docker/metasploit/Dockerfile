# syntax=docker/dockerfile:1.4
FROM ubuntu:22.04

LABEL maintainer="C2-Dploy"
LABEL description="Metasploit Framework Container"

ARG DEBIAN_FRONTEND=noninteractive
USER root
# Installation standard sans cache BuildKit pour compatibilité Terraform
RUN bash -c 'set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update && \
        apt-get install -y --no-install-recommends postgresql postgresql-contrib curl wget && \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache postgresql postgresql-contrib curl wget; \
    else \
        echo "Unsupported base image: no apt-get or apk found" && exit 1; \
    fi'

# Créer le répertoire de données
RUN mkdir -p /root/.msf4
RUN mkdir -p /opt/metasploit/payloads

# Configuration de la base de données
COPY database.yml /root/.msf4/database.yml

# Exposer les ports
EXPOSE 4444 8080

# Script de démarrage
COPY start-metasploit.sh /start-metasploit.sh
RUN chmod +x /start-metasploit.sh

CMD ["/start-metasploit.sh"] 