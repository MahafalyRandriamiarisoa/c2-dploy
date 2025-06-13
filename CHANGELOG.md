# Changelog - C2-Dploy

## [Unreleased] - 2024-12-19

### Ajouté
- **Scripts de setup automatique** pour résoudre les problèmes d'installation
  - `scripts/setup.sh` : Setup complet avec installation automatique des prérequis
  - `scripts/setup-dev.sh` : Setup rapide pour environnements de développement
  - `make setup` : Nouvelle cible Makefile pour le setup automatique

### Amélioré
- **Documentation** mise à jour avec plusieurs options de setup
  - Guide détaillé dans `docs/SETUP.md`
  - Instructions de résolution des problèmes courants
  - Support pour différents environnements (vierge, dev, CI/CD)

### Corrigé
- **Erreur "Couldn't find an alternative telinit implementation to spawn"**
  - Détection automatique de Terraform/OpenTofu
  - Installation automatique des outils manquants
  - Gestion d'erreur améliorée dans `make deps`

### Fonctionnalités des scripts de setup

#### `scripts/setup.sh` (Setup automatique)
- ✅ Vérification des prérequis (Make, Git, Docker, Terraform, Go)
- ✅ Installation automatique des outils manquants
- ✅ Configuration de l'environnement (terraform.tfvars)
- ✅ Installation des dépendances (Go modules, Terraform providers)
- ✅ Tests de validation
- ✅ Support macOS et Linux
- ✅ Messages d'erreur clairs et solutions proposées

#### `scripts/setup-dev.sh` (Setup rapide)
- ✅ Vérification des prérequis existants
- ✅ Configuration de l'environnement
- ✅ Installation des dépendances
- ✅ Pas d'installation automatique (pour environnements contrôlés)

### Cas d'usage couverts

1. **Environnement vierge** : `make setup`
2. **Environnement de développement** : `./scripts/setup-dev.sh`
3. **Environnement CI/CD** : Setup minimal avec `make deps`

### Résolution des problèmes

- Erreur Terraform/OpenTofu manquant
- Problèmes de permissions Docker
- Versions Go incompatibles
- Configuration manquante

### Impact

Ces améliorations permettent :
- **Onboarding plus rapide** : Setup en une commande
- **Moins d'erreurs** : Validation automatique des prérequis
- **Meilleure expérience utilisateur** : Messages clairs et solutions proposées
- **Support multi-environnement** : Adapté aux différents cas d'usage 