#!/bin/bash

set -e

echo "🧪 TEST LOCAL C2 FRAMEWORK - TERRAFORM + DOCKER"
echo "================================================"

# Fonction d'aide
show_usage() {
    echo "Usage: $0 [framework]"
    echo ""
    echo "Frameworks disponibles:"
    echo "  sliver     - Test Sliver C2"
    echo "  havoc      - Test Havoc C2"
    echo "  mythic     - Test Mythic C2" 
    echo "  empire     - Test Empire C2"
    echo "  metasploit - Test Metasploit Framework"
    echo "  all        - Test tous les frameworks"
    echo "  tdd        - Workflow TDD complet"
    echo ""
    echo "Exemple: $0 sliver"
}

# Vérifier les arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

FRAMEWORK=$1

# Vérifier Docker
echo "🔍 Vérification de Docker..."
if ! docker info &> /dev/null; then
    echo "❌ Docker n'est pas disponible"
    exit 1
fi

# Fonction de test d'un framework via Terraform
test_framework() {
    local fw=$1
    echo "🧪 Test Terraform + Docker pour $fw..."
    
    # Test construction de l'image Docker
    echo "🐳 Construction de l'image Docker..."
    if docker build -t "purple-team-${fw}:test" "./docker/${fw}/"; then
        echo "✅ Image Docker $fw construite avec succès"
    else
        echo "❌ Échec de construction de l'image $fw"
        return 1
    fi
    
    # Test validation Terraform
    echo "📋 Validation Terraform..."
    cd terraform
    if terraform validate; then
        echo "✅ Configuration Terraform valide"
    else
        echo "❌ Configuration Terraform invalide"
        cd ..
        return 1
    fi
    cd ..
    
    echo "✅ Test $fw réussi!"
}

# Test TDD complet
test_tdd() {
    echo "🎯 Workflow TDD complet"
    
    # Utiliser le Makefile pour le workflow TDD
    if command -v make &> /dev/null; then
        make ci
    else
        echo "⚠️ Make non disponible, test manuel..."
        
        # Tests manuels
        echo "📝 Validation Terraform..."
        cd terraform && terraform validate && cd ..
        
        echo "🐳 Construction des images Docker..."
        for fw in havoc sliver mythic empire metasploit; do
            echo "Building $fw..."
            docker build -t "purple-team-${fw}:test" "./docker/${fw}/" || return 1
        done
        
        echo "✅ Workflow TDD manuel terminé"
    fi
}

# Exécution des tests
case $FRAMEWORK in
    "sliver"|"havoc"|"mythic"|"empire"|"metasploit")
        echo "🎯 Test de $FRAMEWORK"
        test_framework $FRAMEWORK
        ;;
    "all")
        echo "🎯 Test de tous les frameworks"
        for fw in sliver havoc mythic empire metasploit; do
            echo ""
            echo "================================"
            test_framework $fw
            echo "================================"
        done
        ;;
    "tdd")
        test_tdd
        ;;
    *)
        echo "❌ Framework '$FRAMEWORK' non reconnu"
        show_usage
        exit 1
        ;;
esac

echo ""
echo "🎉 Tests terminés!"
echo ""
echo "💡 Commandes TDD disponibles:"
echo "  make help        - Voir toutes les commandes"
echo "  make test-unit   - Tests unitaires rapides"
echo "  make deploy      - Déploiement complet"
echo "  make tdd         - Workflow TDD complet" 