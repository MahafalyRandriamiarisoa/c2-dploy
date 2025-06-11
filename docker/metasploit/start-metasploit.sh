#!/bin/bash

echo "💥 Démarrage de Metasploit Framework..."

# Démarrer msfrpcd (RPC daemon) en arrière-plan
echo "Démarrage de msfrpcd..."
./msfrpcd -P PurpleTeam2024! -S -f -a 0.0.0.0 -p 8080 &

# Attendre que le RPC soit prêt
sleep 5

echo "💥 Metasploit est prêt!"
echo "RPC: msfrpc://127.0.0.1:8080"
echo "Password: PurpleTeam2024!"

# Garder le container en vie
tail -f /dev/null 