#!/bin/bash

set -e

echo "🚀 C2-DPLOY - DÉPLOIEMENT SIMPLIFIÉ"
echo "========================================"
echo ""
echo "Architecture: Terraform → Docker"
echo "Frameworks: Havoc, Sliver, Mythic, Empire, Metasploit"
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

echo ""
echo "🚀 Déploiement de l'infrastructure..."

# Aller dans le dossier Terraform
cd terraform

# Initialiser Terraform
echo "🏗️ Initialisation de Terraform..."
terraform init

# Déployer l'infrastructure
echo "🚀 Déploiement des containers..."
terraform apply -auto-approve

echo ""
echo "🎉 DÉPLOIEMENT TERMINÉ!"
echo "======================"
echo ""

# Afficher les outputs Terraform
terraform output

echo ""
echo "💡 Commandes utiles:"
echo "  - Status:        docker ps"
echo "  - Logs:          docker logs <container>"
echo "  - Payloads:      ./payloads/generate-all.sh"
echo "  - Arrêter:       terraform destroy"
echo ""
echo "📁 Données persistantes dans: ./data/"
echo "📁 Payloads dans: ./payloads/" 