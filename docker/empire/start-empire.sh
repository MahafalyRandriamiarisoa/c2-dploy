#!/bin/bash

echo "👑 Démarrage d'Empire C2..."

cd /opt/Empire

# Configuration initiale
export EMPIRE_PASSWORD="PurpleTeam2024!"

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
echo "Password: PurpleTeam2024!"

# Garder le container en vie
tail -f /dev/null 