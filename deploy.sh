#!/bin/bash

set -e

echo "🚀 C2-DPLOY"
echo "==================================="
echo ""
echo "Déploiement automatisé des C2:"
echo "🗡️  Havoc"
echo "🐍 Sliver" 
echo "🏛️  Mythic"
echo "👑 Empire"
echo "💥 Metasploit"
echo ""

# Vérifier les prérequis
echo "🔍 Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    echo "Installation: brew install docker"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform n'est pas installé"
    echo "Installation: brew install terraform"
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible n'est pas installé"
    echo "Installation: brew install ansible"
    exit 1
fi

echo "✅ Tous les prérequis sont installés"

# Démarrer Docker si nécessaire
if ! docker info &> /dev/null; then
    echo "🐳 Démarrage de Docker..."
    open -a Docker
    echo "⏳ Attente que Docker soit prêt..."
    
    while ! docker info &> /dev/null; do
        sleep 2
    done
    echo "✅ Docker est prêt"
fi

# Créer les répertoires nécessaires
echo "📁 Création des répertoires..."
mkdir -p data/{havoc,sliver,mythic,empire,metasploit}
mkdir -p payloads

# Lancer le déploiement Ansible
echo "🚀 Lancement du déploiement..."
cd ansible-playbooks
ansible-playbook -i localhost, deploy-all-c2.yaml

echo ""
echo "🎉 DÉPLOIEMENT TERMINÉ!"
echo "======================"
echo ""
echo "🌐 Interfaces disponibles:"
echo "🗡️  Havoc:      https://localhost:8443"
echo "🐍 Sliver:     CLI via: docker exec -it sliver-c2 sliver"
echo "🏛️  Mythic:     https://localhost:7443"
echo "👑 Empire:     http://localhost:5000"
echo "💥 Metasploit: CLI via: docker exec -it metasploit-c2 msfconsole"
echo ""
echo "📁 Payloads générés dans: ./payloads/"
echo ""
echo "🔐 Credentials par défaut:"
echo "- Mythic: mythic_admin / PurpleTeam2024!"
echo "- Empire: PurpleTeam2024!"
echo "- Metasploit RPC: PurpleTeam2024!"
echo ""
echo "💡 Pour arrêter: terraform destroy (dans le dossier terraform/)" 