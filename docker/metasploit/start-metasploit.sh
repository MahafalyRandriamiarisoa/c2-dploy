#!/bin/bash
set -euo pipefail

: "${METASPLOIT_RPC_PASSWORD:?METASPLOIT_RPC_PASSWORD env var required (défini par Terraform)}"
: "${METASPLOIT_DB_PASSWORD:?METASPLOIT_DB_PASSWORD env var required (défini par Terraform)}"

echo "💥 Démarrage de Metasploit Framework..."

# Générer database.yml à partir du template (évite de hardcoder le mdp DB dans l'image)
sed "s|{{DB_PASSWORD}}|${METASPLOIT_DB_PASSWORD}|" \
    /root/.msf4/database.yml.tmpl > /root/.msf4/database.yml

# Lancer PostgreSQL
echo "Démarrage de PostgreSQL..."
su postgres -c "pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/data/logfile start"

# Créer la base msf si nécessaire
su postgres -c "psql -c \"CREATE USER msf WITH PASSWORD '${METASPLOIT_DB_PASSWORD}';\"" 2>/dev/null || \
  su postgres -c "psql -c \"ALTER USER msf WITH PASSWORD '${METASPLOIT_DB_PASSWORD}';\"" 2>/dev/null || true
su postgres -c "psql -c \"CREATE DATABASE msf_database OWNER msf;\"" 2>/dev/null || true

# Démarrer msfrpcd (RPC daemon) en arrière-plan
echo "Démarrage de msfrpcd..."
./msfrpcd -P "${METASPLOIT_RPC_PASSWORD}" -S -f -a 0.0.0.0 -p 8080 &

# Attendre que les services soient prêts
sleep 5

echo "💥 Metasploit est prêt!"
echo "RPC: msfrpc://127.0.0.1:8080"
echo "Password: (défini via METASPLOIT_RPC_PASSWORD)"

# Garder le container en vie
tail -f /dev/null
