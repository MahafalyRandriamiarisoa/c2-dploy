#!/bin/bash

# C2-Dploy - Script de setup rapide pour développement
# Usage: ./scripts/setup-dev.sh

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

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  ⚡ C2-Dploy Setup Dev                       ║${NC}"
echo -e "${BLUE}║            Vérification rapide des prérequis                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Fonction pour afficher les erreurs
error_exit() {
    echo -e "${RED}❌ ERREUR: $1${NC}" >&2
    exit 1
}

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fonction pour obtenir la version d'une commande
get_version() {
    local cmd="$1"
    local version_flag="$2"
    if command_exists "$cmd"; then
        "$cmd" $version_flag 2>/dev/null | head -n1 || echo "version inconnue"
    else
        echo "non installé"
    fi
}

# Vérification des prérequis
echo -e "${CYAN}🔍 Vérification des prérequis...${NC}"
echo ""

PREREQS_OK=true

# Vérifier Make
if ! command_exists make; then
    echo -e "${RED}❌ Make: non installé${NC}"
    PREREQS_OK=false
else
    echo -e "${GREEN}✅ Make: $(get_version make --version)${NC}"
fi

# Vérifier Docker
if ! command_exists docker; then
    echo -e "${RED}❌ Docker: non installé${NC}"
    PREREQS_OK=false
else
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker: installé mais ne fonctionne pas${NC}"
        PREREQS_OK=false
    else
        echo -e "${GREEN}✅ Docker: $(get_version docker --version)${NC}"
    fi
fi

# Vérifier Terraform/OpenTofu
if ! command_exists terraform && ! command_exists tofu; then
    echo -e "${RED}❌ Terraform/OpenTofu: non installé${NC}"
    PREREQS_OK=false
else
    if command_exists terraform; then
        echo -e "${GREEN}✅ Terraform: $(get_version terraform --version)${NC}"
    fi
    if command_exists tofu; then
        echo -e "${GREEN}✅ OpenTofu: $(get_version tofu --version)${NC}"
    fi
fi

# Vérifier Go
if ! command_exists go; then
    echo -e "${RED}❌ Go: non installé${NC}"
    PREREQS_OK=false
else
    go_version=$(get_version go version)
    if [[ "$go_version" == *"go1.21"* ]] || [[ "$go_version" == *"go1.22"* ]] || [[ "$go_version" == *"go1.23"* ]]; then
        echo -e "${GREEN}✅ Go: $go_version${NC}"
    else
        echo -e "${YELLOW}⚠️  Go: $go_version (version recommandée: 1.21+)${NC}"
    fi
fi

# Vérifier Git
if ! command_exists git; then
    echo -e "${RED}❌ Git: non installé${NC}"
    PREREQS_OK=false
else
    echo -e "${GREEN}✅ Git: $(get_version git --version)${NC}"
fi

echo ""

if [ "$PREREQS_OK" = false ]; then
    echo -e "${RED}❌ Certains prérequis ne sont pas satisfaits.${NC}"
    echo -e "${YELLOW}💡 Lancez './scripts/setup.sh' pour une installation automatique.${NC}"
    exit 1
fi

echo -e "${CYAN}🔧 Configuration de l'environnement...${NC}"

# Créer le fichier terraform.tfvars s'il n'existe pas
if [ ! -f "$PROJECT_ROOT/terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}📝 Création du fichier de configuration par défaut...${NC}"
    cp "$PROJECT_ROOT/terraform/terraform.tfvars.example" "$PROJECT_ROOT/terraform/terraform.tfvars"
    echo -e "${GREEN}✅ Fichier terraform.tfvars créé${NC}"
else
    echo -e "${GREEN}✅ Fichier terraform.tfvars déjà présent${NC}"
fi

# Vérifier les permissions du script deploy-selector
if [ -f "$PROJECT_ROOT/scripts/deploy-selector.sh" ]; then
    chmod +x "$PROJECT_ROOT/scripts/deploy-selector.sh"
    echo -e "${GREEN}✅ Permissions du script deploy-selector mises à jour${NC}"
fi

echo ""
echo -e "${CYAN}📦 Installation des dépendances...${NC}"

# Installer les dépendances Go
echo -e "${YELLOW}📥 Téléchargement des modules Go...${NC}"
cd "$PROJECT_ROOT/tests"
if [ -f "go.mod" ]; then
    go mod download
    echo -e "${GREEN}✅ Modules Go téléchargés${NC}"
else
    echo -e "${YELLOW}⚠️  Fichier go.mod non trouvé dans tests/${NC}"
fi

# Initialiser Terraform
echo -e "${YELLOW}🏗️  Initialisation de Terraform...${NC}"
cd "$PROJECT_ROOT/terraform"

# Déterminer quel binaire Terraform utiliser
TF_BIN=""
if command_exists terraform; then
    TF_BIN="terraform"
elif command_exists tofu; then
    TF_BIN="tofu"
else
    error_exit "Aucun binaire Terraform/OpenTofu trouvé"
fi

# Initialiser Terraform avec gestion d'erreur
if $TF_BIN init -backend=false >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform initialisé${NC}"
else
    echo -e "${YELLOW}⚠️  Terraform init a échoué, mais cela peut être normal pour la validation${NC}"
fi

# Retourner au répertoire racine
cd "$PROJECT_ROOT"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  🎉 Setup Dev terminé !                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}🚀 Prochaines étapes:${NC}"
echo ""
echo -e "1. ${BLUE}Configuration personnalisée:${NC}"
echo -e "   make configure"
echo ""
echo -e "2. ${BLUE}Déploiement rapide:${NC}"
echo -e "   make deploy-modern    # Frameworks modernes (Havoc, Sliver, Mythic)"
echo -e "   make deploy-havoc     # Seulement Havoc"
echo -e "   make deploy-sliver    # Seulement Sliver"
echo ""
echo -e "3. ${BLUE}Tests:${NC}"
echo -e "   make test-unit        # Tests unitaires"
echo -e "   make test             # Tous les tests"
echo ""
echo -e "4. ${BLUE}Aide:${NC}"
echo -e "   make help             # Voir toutes les commandes"
echo ""

echo -e "${GREEN}✨ C2-Dploy est prêt à être utilisé !${NC}" 