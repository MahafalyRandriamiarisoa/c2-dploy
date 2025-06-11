#!/bin/bash

echo "🐍 Démarrage de Sliver C2..."

# Générer les certificats si nécessaire
if [ ! -f /root/.sliver/certs/sliver-ca-cert.pem ]; then
    echo "Génération des certificats..."
    sliver-server unpack --force
fi

# Créer la configuration par défaut
cat > /root/.sliver/configs/multiplayer.cfg << EOF
{
    "daemon": {
        "host": "0.0.0.0",
        "port": 31337
    },
    "job_timeout": 60,
    "default_timeout": 60
}
EOF

# Démarrer le daemon Sliver
echo "Démarrage du Sliver daemon..."
sliver-server daemon &

# Attendre que le daemon soit prêt
sleep 5

# Créer un utilisateur par défaut
echo "Création de l'utilisateur purple-team..."
sliver-server operator --name purple-team --lhost 0.0.0.0 --save /root/.sliver/

# Garder le container en vie
tail -f /dev/null 