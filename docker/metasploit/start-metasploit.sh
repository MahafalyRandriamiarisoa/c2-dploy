#!/bin/bash

echo "💥 Démarrage de Metasploit Framework..."

# Lancer PostgreSQL
echo "Démarrage de PostgreSQL..."
su postgres -c "pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/data/logfile start"

# Créer la base msf si nécessaire
su postgres -c "psql -c \"CREATE USER msf WITH PASSWORD 'msf';\"" 2>/dev/null || true
su postgres -c "psql -c \"CREATE DATABASE msf_database OWNER msf;\"" 2>/dev/null || true

# Démarrer msfrpcd (RPC daemon) en arrière-plan
echo "Démarrage de msfrpcd..."
./msfrpcd -P PurpleTeam2024! -S -f -a 0.0.0.0 -p 8080 &

# Attendre que les services soient prêts
sleep 5

echo "💥 Metasploit est prêt!"
echo "RPC: msfrpc://127.0.0.1:8080"
echo "Password: PurpleTeam2024!"

# Garder le container en vie
tail -f /dev/null
