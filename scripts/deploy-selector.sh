#!/bin/bash

# Script interactif de sélection de frameworks C2
# Usage: ./scripts/deploy-selector.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="$PROJECT_ROOT/terraform/terraform.tfvars"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  🎯 C2-Dploy Selector                        ║${NC}"
echo -e "${BLUE}║            Sélecteur de Frameworks C2                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Fonction pour demander oui/non
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    while true; do
        if [ "$default" = "true" ]; then
            read -p "$prompt [Y/n]: " choice
            choice=${choice:-Y}
        else
            read -p "$prompt [y/N]: " choice
            choice=${choice:-N}
        fi
        
        case $choice in
            [Yy]* ) echo "true"; return;;
            [Nn]* ) echo "false"; return;;
            * ) echo "Répondez par 'y' (oui) ou 'n' (non).";;
        esac
    done
}

echo -e "${CYAN}🔧 Configuration des frameworks C2 à déployer:${NC}"
echo ""

# Sélection des frameworks
echo -e "${YELLOW}🗡️  Havoc C2${NC} - Framework moderne avec évasion avancée"
DEPLOY_HAVOC=$(ask_yes_no "Déployer Havoc C2?" "true")

echo ""
echo -e "${YELLOW}🐍 Sliver C2${NC} - Framework Go cross-platform"
DEPLOY_SLIVER=$(ask_yes_no "Déployer Sliver C2?" "true")

echo ""
echo -e "${YELLOW}🏛️  Mythic C2${NC} - Framework complet avec interface web"
DEPLOY_MYTHIC=$(ask_yes_no "Déployer Mythic C2?" "true")

echo ""
echo -e "${YELLOW}👑 Empire C2${NC} - Framework PowerShell classique"
DEPLOY_EMPIRE=$(ask_yes_no "Déployer Empire C2?" "false")

echo ""
echo -e "${YELLOW}💥 Metasploit${NC} - Framework de référence"
DEPLOY_METASPLOIT=$(ask_yes_no "Déployer Metasploit C2?" "false")

echo ""
echo -e "${CYAN}🌐 Configuration réseau et environnement:${NC}"

echo ""
read -p "Nom de l'environnement [dev]: " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

echo ""
read -p "Subnet réseau [172.20.0.0/16]: " NETWORK_SUBNET
NETWORK_SUBNET=${NETWORK_SUBNET:-172.20.0.0/16}

echo ""
echo -e "${RED}🔐 Sécurité - Mot de passe admin des C2 (minimum 12 caractères):${NC}"
while true; do
    read -s -p "Mot de passe admin: " DEFAULT_PASSWORD
    echo ""
    if [ "${#DEFAULT_PASSWORD}" -ge 12 ]; then
        break
    fi
    echo -e "${RED}❌ Le mot de passe doit faire au moins 12 caractères.${NC}"
done

# Génération du fichier terraform.tfvars
echo ""
echo -e "${BLUE}📝 Génération du fichier terraform.tfvars...${NC}"

cat > "$TFVARS_FILE" << EOF
# Configuration générée par deploy-selector.sh
# Date: $(date)

# Configuration de déploiement des frameworks C2
deploy_havoc      = $DEPLOY_HAVOC
deploy_sliver     = $DEPLOY_SLIVER
deploy_mythic     = $DEPLOY_MYTHIC
deploy_empire     = $DEPLOY_EMPIRE
deploy_metasploit = $DEPLOY_METASPLOIT

# Configuration environnement
environment = "$ENVIRONMENT"

# Configuration réseau
network_subnet = "$NETWORK_SUBNET"

# Domaine de base
base_domain = "localhost"

# Mot de passe par défaut (modifiez selon vos besoins)
default_password = "$DEFAULT_PASSWORD"
EOF

echo -e "${GREEN}✅ Fichier terraform.tfvars créé avec succès!${NC}"
echo ""

# Affichage du résumé
echo -e "${PURPLE}📊 Résumé de la configuration:${NC}"
echo "────────────────────────────────────────"
[ "$DEPLOY_HAVOC" = "true" ] && echo -e "🗡️  Havoc C2:      ${GREEN}✓ Activé${NC}" || echo -e "🗡️  Havoc C2:      ${RED}✗ Désactivé${NC}"
[ "$DEPLOY_SLIVER" = "true" ] && echo -e "🐍 Sliver C2:     ${GREEN}✓ Activé${NC}" || echo -e "🐍 Sliver C2:     ${RED}✗ Désactivé${NC}"
[ "$DEPLOY_MYTHIC" = "true" ] && echo -e "🏛️  Mythic C2:     ${GREEN}✓ Activé${NC}" || echo -e "🏛️  Mythic C2:     ${RED}✗ Désactivé${NC}"
[ "$DEPLOY_EMPIRE" = "true" ] && echo -e "👑 Empire C2:     ${GREEN}✓ Activé${NC}" || echo -e "👑 Empire C2:     ${RED}✗ Désactivé${NC}"
[ "$DEPLOY_METASPLOIT" = "true" ] && echo -e "💥 Metasploit:    ${GREEN}✓ Activé${NC}" || echo -e "💥 Metasploit:    ${RED}✗ Désactivé${NC}"
echo "────────────────────────────────────────"
echo -e "🌍 Environnement: ${CYAN}$ENVIRONMENT${NC}"
echo -e "🌐 Réseau:        ${CYAN}$NETWORK_SUBNET${NC}"
echo ""

# Proposition de déploiement
echo -e "${YELLOW}🚀 Prêt à déployer!${NC}"
echo ""
echo "Commandes disponibles:"
echo -e "  ${BLUE}make deploy-custom${NC}     - Déployer avec votre configuration"
echo -e "  ${BLUE}make validate${NC}          - Valider la configuration"
echo -e "  ${BLUE}make plan${NC}              - Voir le plan de déploiement"
echo ""

if ask_yes_no "Lancer le déploiement maintenant?" "false"; then
    echo ""
    echo -e "${BLUE}🚀 Lancement du déploiement...${NC}"
    cd "$PROJECT_ROOT"
    make deploy-custom
else
    echo ""
    echo -e "${YELLOW}💡 Configuration sauvegardée dans ${TFVARS_FILE}${NC}"
    echo -e "${YELLOW}💡 Lancez 'make deploy-custom' quand vous serez prêt.${NC}"
fi 