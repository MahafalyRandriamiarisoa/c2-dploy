# syntax=docker/dockerfile:1.4
FROM metasploitframework/metasploit-framework:latest

LABEL maintainer="C2-Dploy"
LABEL description="Metasploit Framework Container"
LABEL version="2.0"

USER root

# Installation minimale d'outils nécessaires
RUN apk add --no-cache curl wget netcat-openbsd

# Créer le répertoire de données
RUN mkdir -p /root/.msf4
RUN mkdir -p /opt/metasploit/payloads

# Exposer les ports
EXPOSE 4444 8080

# Script de démarrage simple
COPY start-metasploit.sh /start-metasploit.sh
RUN chmod +x /start-metasploit.sh

# Utiliser le répertoire de travail par défaut de l'image officielle
WORKDIR /usr/src/metasploit-framework

CMD ["/start-metasploit.sh"] 