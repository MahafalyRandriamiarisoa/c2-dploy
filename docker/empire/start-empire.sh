#!/bin/bash
set -euo pipefail

: "${EMPIRE_PASSWORD:?EMPIRE_PASSWORD env var required (défini par Terraform)}"

echo "👑 Démarrage d'Empire C2..."

cd /opt/Empire

# Créer la base de données
echo "Initialisation de la base de données..."
python3 empire.py --setup

# Démarrer Empire server
echo "Démarrage d'Empire server..."
python3 empire.py server &

# Attendre que le serveur soit prêt
sleep 10

echo "👑 Empire C2 est prêt!"
echo "REST API: http://localhost:1337"
echo "Interface Web: http://localhost:5000"
echo "Password: (défini via EMPIRE_PASSWORD)"

# Garder le container en vie
tail -f /dev/null