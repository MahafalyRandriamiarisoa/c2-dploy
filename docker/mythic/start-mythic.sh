#!/bin/bash

echo "🏛️  Démarrage de Mythic C2..."

cd /opt/Mythic

# Configuration initiale
export MYTHIC_ADMIN_PASSWORD="PurpleTeam2024!"
export MYTHIC_ADMIN_USER="mythic_admin"
export MYTHIC_SERVER_PORT=7443
export MYTHIC_DEBUG=false

# Installer les agents par défaut
echo "Installation des agents Mythic..."
./mythic-cli install github https://github.com/MythicAgents/apfell
./mythic-cli install github https://github.com/MythicAgents/apollo

# Démarrer Mythic
echo "Démarrage de Mythic..."
./mythic-cli start

# Attendre que Mythic soit prêt
sleep 30

echo "🏛️  Mythic C2 est prêt!"
echo "Interface: https://localhost:7443"
echo "Admin: mythic_admin / PurpleTeam2024!"

# Garder le container en vie
tail -f mythic.log 