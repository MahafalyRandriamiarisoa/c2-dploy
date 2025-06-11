#!/bin/bash

echo "🗡️  Démarrage de Havoc C2..."

# Créer la configuration par défaut si elle n'existe pas
if [ ! -f /opt/havoc/data/config.json ]; then
    cat > /opt/havoc/data/config.json << EOF
{
    "server": {
        "host": "0.0.0.0",
        "port": 40056,
        "secure": true
    },
    "listeners": [
        {
            "name": "HTTPS",
            "type": "https",
            "port": 443,
            "secure": true
        }
    ]
}
EOF
fi

cd /opt/havoc

# Démarrer le teamserver Havoc
echo "Démarrage du Havoc Teamserver..."
./havoc server --profile /opt/havoc/data/config.json

# Garder le container en vie
tail -f /dev/null 