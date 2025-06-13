# C2-Dploy

C2-Dploy est une infrastructure-as-code permettant de déployer en quelques minutes un laboratoire complet de frameworks Command & Control (C2) pour la recherche offensive, la formation et le purple teaming. L'objectif est d'obtenir un environnement reproductible, testé et facilement extensible, reposant uniquement sur des composants open-source.

## Frameworks inclus

- Havoc
- Sliver
- Mythic (RabbitMQ + Postgres + core + UI)
- Empire
- Metasploit

Le tout est interconnecté sur le réseau Docker `purple-team-net` et exposé localement :

| Framework  | Accès local                                      |
|------------|--------------------------------------------------|
| Havoc      | https://localhost:8443                           |
| Sliver     | `docker exec -it sliver-c2 sliver`               |
| Mythic     | https://localhost:7443                           |
| Empire     | http://localhost:5000                            |
| Metasploit | `docker exec -it metasploit-c2 msfconsole`       |

## Architecture technique

```
┌────────────────────┐     ┌──────────────────┐
│   Terraform (IaC)  │ ──▶ │   Docker Engine  │
└────────────────────┘     └──────────────────┘
           │                         │
           │ tests                   │ images
           ▼                         ▼
   Terratest (Go)            Dockerfiles spécifiques
```

1. Terraform provisionne les containers, réseaux et volumes persistants.
2. Les images Docker minimalistes sont construites via un Makefile optimisé pour BuildKit.
3. Terratest valide automatiquement la configuration et l'état de santé des services.
4. Le Makefile centralise l'ensemble des tâches (tests, build, deploy, destroy, clean).

## Prérequis

- macOS ou Linux avec :
  - Docker ≥ 20.10
  - Terraform ≥ 1.6 ou [OpenTofu](https://opentofu.org)
  - Go ≥ 1.21 (exécution des tests)
  - Make

## Mise en route rapide

### Option 1 : Setup automatique (recommandé)

```bash
# 1. Récupération du dépôt
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy

# 2. Setup automatique (vérifie et installe les prérequis)
make setup

# 3. Configuration personnalisée (optionnel)
make configure

# 4. Déploiement complet
make deploy

# 5. Vérification des containers et des ports
make status
```

### Option 2 : Setup manuel

```bash
# 1. Récupération du dépôt
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy

# 2. Vérification des prérequis (sans installation automatique)
./scripts/setup-dev.sh

# 3. Installation des dépendances
make deps

# 4. Déploiement complet
make deploy

# 5. Vérification des containers et des ports
make status
```

### Option 3 : Setup minimal

```bash
# 1. Récupération du dépôt
git clone https://github.com/USERNAME/c2-dploy.git
cd c2-dploy

# 2. Copie de la configuration par défaut
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 3. Installation des dépendances
make deps

# 4. Déploiement complet
make deploy
```

Pour détruire l'infrastructure :

```bash
make destroy
```

## Scripts de setup

Le projet inclut deux scripts de setup :

- **`scripts/setup.sh`** : Setup complet avec installation automatique des prérequis
- **`scripts/setup-dev.sh`** : Setup rapide avec vérification des prérequis existants

### Résolution des problèmes courants

Si vous rencontrez l'erreur `Couldn't find an alternative telinit implementation to spawn` :

```bash
# Solution 1 : Setup automatique
make setup

# Solution 2 : Installation manuelle de Terraform/OpenTofu
# Sur macOS :
brew install opentofu

# Sur Ubuntu/Debian :
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform
```

## Workflow de développement (TDD)

Le projet adopte une approche Test-Driven Development.

```bash
# Suite rapide (validation + plan)
make test-unit

# Workflow intégral : formattage, tests, build, déploiement, tests d'intégration
make tdd
```

## Structure du dépôt

```
.
├── terraform/        # Définition de l'infrastructure
├── docker/           # Dockerfiles et scripts de démarrage
├── tests/            # Suites Terratest (Go)
├── Makefile          # Commandes principales
└── payloads/         # Répertoire cible pour les payloads générés
```

## Identifiants par défaut

| Service   | Utilisateur         | Mot de passe        |
|-----------|---------------------|---------------------|
| Mythic    | mythic_admin        | PurpleTeam2024!     |
| Empire    | –                   | PurpleTeam2024!     |
| Metasploit RPC | –             | PurpleTeam2024!     |

## Ajout d'un nouveau framework C2

1. Créer une image dans `docker/mon_c2/` avec un `Dockerfile` et, si nécessaire, des scripts de démarrage.
2. Définir les ressources `docker_image` et `docker_container` correspondantes dans `terraform/`.
3. Ajouter les tests associés dans `tests/`.
4. Mettre à jour les variables `FRAMEWORKS` et la cible `docker-build` du `Makefile`.

## Sécurité et usage responsable

Cette infrastructure est fournie uniquement à des fins éducatives et de recherche sur environnement contrôlé. Toute utilisation contre des systèmes sans consentement explicite est illégale. Les auteurs et contributeurs déclinent toute responsabilité quant à un usage malveillant.

## Licence

Distributed under the MIT License. See `LICENSE` for more information. 
