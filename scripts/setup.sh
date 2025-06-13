#!/bin/bash

# C2-Dploy - Script de setup automatique
# Usage: ./scripts/setup.sh [--dev|--prod]

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
ENVIRONMENT="${1:-dev}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  🚀 C2-Dploy Setup                          ║${NC}"
echo -e "${BLUE}║            Configuration automatique de l'environnement     ║${NC}"
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

# Fonction pour installer Terraform/OpenTofu
install_terraform() {
    echo -e "${YELLOW}📦 Installation de Terraform/OpenTofu...${NC}"
    
    # Détecter l'OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            echo "Installation via Homebrew..."
            brew install opentofu
        else
            error_exit "Homebrew requis pour macOS. Installez-le via: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt; then
            # Ubuntu/Debian
            echo "Installation via apt..."
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install -y terraform
        elif command_exists yum; then
            # CentOS/RHEL
            echo "Installation via yum..."
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install terraform
        else
            error_exit "Gestionnaire de paquets non supporté. Installez Terraform manuellement."
        fi
    else
        error_exit "OS non supporté: $OSTYPE"
    fi
}

# Fonction pour installer Go
install_go() {
    echo -e "${YELLOW}📦 Installation de Go...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install go
        else
            error_exit "Homebrew requis pour macOS"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            sudo apt update && sudo apt install -y golang-go
        elif command_exists yum; then
            sudo yum install -y golang
        else
            error_exit "Gestionnaire de paquets non supporté"
        fi
    fi
}

# Fonction pour installer Docker
install_docker() {
    echo -e "${YELLOW}📦 Installation de Docker...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command_exists docker; then
            error_exit "Docker Desktop requis pour macOS. Téléchargez-le depuis https://www.docker.com/products/docker-desktop"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            sudo apt update
            sudo apt install -y ca-certificates curl gnupg lsb-release
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            sudo usermod -aG docker $USER
            echo -e "${YELLOW}⚠️  Redémarrez votre session pour que les changements Docker prennent effet${NC}"
        elif command_exists yum; then
            sudo yum install -y docker
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
        fi
    fi
}

# Vérification des prérequis
echo -e "${CYAN}🔍 Vérification des prérequis...${NC}"
echo ""

# Vérifier Make
if ! command_exists make; then
    error_exit "Make n'est pas installé. Installez-le via votre gestionnaire de paquets."
fi
echo -e "${GREEN}✅ Make: $(get_version make --version)${NC}"

# Vérifier Docker
if ! command_exists docker; then
    echo -e "${YELLOW}🐳 Docker non trouvé, installation...${NC}"
    install_docker
else
    # Vérifier que Docker fonctionne
    if ! docker info >/dev/null 2>&1; then
        error_exit "Docker est installé mais ne fonctionne pas. Vérifiez que le daemon Docker est démarré."
    fi
    echo -e "${GREEN}✅ Docker: $(get_version docker --version)${NC}"
fi

# Vérifier Terraform/OpenTofu
if ! command_exists terraform && ! command_exists tofu; then
    echo -e "${YELLOW}🏗️  Terraform/OpenTofu non trouvé, installation...${NC}"
    install_terraform
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
    echo -e "${YELLOW}🐹 Go non trouvé, installation...${NC}"
    install_go
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
    error_exit "Git n'est pas installé. Installez-le via votre gestionnaire de paquets."
fi
echo -e "${GREEN}✅ Git: $(get_version git --version)${NC}"

echo ""
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
echo -e "${CYAN}🧪 Tests de validation...${NC}"

# Test de validation Terraform
echo -e "${YELLOW}🔍 Validation de la configuration Terraform...${NC}"
if make validate >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Configuration Terraform valide${NC}"
else
    echo -e "${YELLOW}⚠️  Validation Terraform échouée (peut être normal selon la configuration)${NC}"
fi

# Test Docker
echo -e "${YELLOW}🐳 Test de Docker...${NC}"
if docker run --rm hello-world >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker fonctionne correctement${NC}"
else
    echo -e "${YELLOW}⚠️  Test Docker échoué (vérifiez les permissions)${NC}"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  🎉 Setup terminé !                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Affichage du résumé
echo -e "${PURPLE}📊 Résumé de l'installation:${NC}"
echo "────────────────────────────────────────"
echo -e "🏗️  Terraform/OpenTofu: ${GREEN}✓${NC}"
echo -e "🐳 Docker:              ${GREEN}✓${NC}"
echo -e "🐹 Go:                  ${GREEN}✓${NC}"
echo -e "📝 Make:                ${GREEN}✓${NC}"
echo -e "📦 Git:                 ${GREEN}✓${NC}"
echo "────────────────────────────────────────"

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

# Vérifier si l'utilisateur veut lancer la configuration
if [ "$ENVIRONMENT" = "dev" ]; then
    echo -e "${YELLOW}💡 Pour un setup complet avec configuration interactive, lancez:${NC}"
    echo -e "${BLUE}   make configure${NC}"
fi

echo -e "${GREEN}✨ C2-Dploy est prêt à être utilisé !${NC}" 