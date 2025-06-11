# syntax=docker/dockerfile:1.4
ARG DEBIAN_FRONTEND=noninteractive

FROM itsafeature/mythic_server:latest

LABEL maintainer="C2-Dploy"
LABEL description="Mythic C2 Framework (image officielle)"

# Pas de compilation : on expose simplement les ports d'interface
EXPOSE 7443 17443

# Script de démarrage simplifié (utilise mythic-cli déjà présent)
CMD ["mythic-cli", "start", "--no-tracking"] 