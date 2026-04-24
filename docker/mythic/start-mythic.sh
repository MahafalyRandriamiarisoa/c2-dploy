#!/bin/bash
set -euo pipefail

: "${MYTHIC_ADMIN_PASSWORD:?MYTHIC_ADMIN_PASSWORD env var required (défini par Terraform)}"
: "${MYTHIC_ADMIN_USER:=mythic_admin}"

echo "🏛️  Démarrage de Mythic C2..."

cd /opt/Mythic

export MYTHIC_ADMIN_USER
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
echo "Admin: ${MYTHIC_ADMIN_USER} (mot de passe défini via MYTHIC_ADMIN_PASSWORD)"

# Garder le container en vie
tail -f mythic.log