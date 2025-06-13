# Guide de Setup - C2-Dploy

Ce guide explique comment configurer l'environnement C2-Dploy pour différents cas d'usage.

## Vue d'ensemble

C2-Dploy propose plusieurs options de setup pour s'adapter à différents environnements :

- **Setup automatique** : Installation complète des prérequis
- **Setup développement** : Vérification des prérequis existants
- **Setup minimal** : Configuration manuelle

## Scripts disponibles

### 1. `scripts/setup.sh` - Setup automatique complet

**Usage :** `make setup` ou `./scripts/setup.sh`

**Fonctionnalités :**
- ✅ Vérification des prérequis
- ✅ Installation automatique des outils manquants
- ✅ Configuration de l'environnement
- ✅ Installation des dépendances
- ✅ Tests de validation

**Prérequis :**
- Make
- Git
- Accès sudo (pour l'installation des paquets)

**Installations automatiques :**
- Docker (Linux uniquement, macOS nécessite Docker Desktop)
- Terraform/OpenTofu
- Go
- Dépendances système

### 2. `scripts/setup-dev.sh` - Setup rapide pour développement

**Usage :** `./scripts/setup-dev.sh`

**Fonctionnalités :**
- ✅ Vérification des prérequis existants
- ✅ Configuration de l'environnement
- ✅ Installation des dépendances
- ❌ Pas d'installation automatique

**Prérequis :**
- Docker ≥ 20.10
- Terraform ≥ 1.6 ou OpenTofu
- Go ≥ 1.21
- Make
- Git

## Cas d'usage

### Environnement vierge (nouvelle machine)

```bash
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy
make setup
```

### Environnement de développement (prérequis installés)

```bash
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy
./scripts/setup-dev.sh
```

### Environnement CI/CD

```bash
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make deps
```

## Résolution des problèmes

### Erreur "Couldn't find an alternative telinit implementation to spawn"

**Cause :** Terraform/OpenTofu non installé ou mal configuré

**Solutions :**

1. **Setup automatique :**
   ```bash
   make setup
   ```

2. **Installation manuelle :**
   
   **macOS :**
   ```bash
   brew install opentofu
   ```
   
   **Ubuntu/Debian :**
   ```bash
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt update && sudo apt install terraform
   ```
   
   **CentOS/RHEL :**
   ```bash
   sudo yum install -y yum-utils
   sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
   sudo yum -y install terraform
   ```

### Erreur Docker "permission denied"

**Cause :** Utilisateur non dans le groupe docker

**Solutions :**

1. **Linux :**
   ```bash
   sudo usermod -aG docker $USER
   # Redémarrer la session
   ```

2. **macOS :**
   - Vérifier que Docker Desktop est démarré
   - Redémarrer Docker Desktop si nécessaire

### Erreur Go "command not found"

**Solutions :**

1. **Setup automatique :**
   ```bash
   make setup
   ```

2. **Installation manuelle :**
   
   **macOS :**
   ```bash
   brew install go
   ```
   
   **Ubuntu/Debian :**
   ```bash
   sudo apt update && sudo apt install -y golang-go
   ```

## Configuration post-setup

Après le setup, vous pouvez personnaliser la configuration :

```bash
# Configuration interactive
make configure

# Ou édition manuelle
nano terraform/terraform.tfvars
```

### Variables importantes

```hcl
# Frameworks à déployer
deploy_havoc      = true   # Havoc C2
deploy_sliver     = true   # Sliver C2
deploy_mythic     = true   # Mythic C2
deploy_empire     = false  # Empire C2
deploy_metasploit = false  # Metasploit

# Sécurité
default_password = "PurpleTeam2024!"  # Changez en production !

# Réseau
network_subnet = "172.20.0.0/16"
```

## Vérification du setup

Après le setup, vérifiez que tout fonctionne :

```bash
# Test de validation
make validate

# Test des images Docker
make docker-test

# Déploiement de test
make deploy-havoc
```

## Support

Si vous rencontrez des problèmes :

1. Vérifiez les prérequis : `./scripts/setup-dev.sh`
2. Consultez les logs : `make validate`
3. Nettoyez et recommencez : `make clean && make setup`
4. Ouvrez une issue sur GitHub avec les logs d'erreur 