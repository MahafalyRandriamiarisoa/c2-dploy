#!/bin/bash

echo "🛑 ARRÊT DE C2-DPLOY"
echo "======================="
echo ""

# Demander confirmation
read -p "Êtes-vous sûr de vouloir arrêter tous les C2? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Arrêt annulé"
    exit 0
fi

echo "🛑 Arrêt en cours..."

# Lancer le playbook d'arrêt
cd ansible-playbooks
ansible-playbook -i localhost, destroy-c2.yaml

echo ""
echo "✅ C2-DPLOY arrêté avec succès!"
echo ""
echo "💡 Pour redémarrer: ./deploy.sh" 