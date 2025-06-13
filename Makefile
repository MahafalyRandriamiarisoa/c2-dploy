# C2-Dploy - Makefile TDD
.PHONY: help test test-unit test-integration deploy destroy clean fmt validate havoc-bin

# Variables
TERRAFORM_DIR := terraform
TESTS_DIR := tests
DOCKER_DIR := docker
FRAMEWORKS := havoc sliver metasploit
BUILD_CACHE_DIR ?= $(HOME)/.docker-build-cache
CPU_CORES ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc || echo 4)
HAVOC_BIN := $(DOCKER_DIR)/havoc/bin/havoc
REGISTRY ?=
TF_BIN ?= $(shell command -v terraform 2>/dev/null || command -v tofu)

# Couleurs pour l'affichage
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Active BuildKit pour accélérer les builds Docker
export DOCKER_BUILDKIT=1

help: ## Afficher l'aide
	@echo "$(BLUE)C2-Dploy - TDD Workflow$(NC)"
	@echo "================================"
	@echo ""
	@echo "$(YELLOW)Tests:$(NC)"
	@echo "  test             - Lancer tous les tests"
	@echo "  test-unit        - Tests unitaires (rapides)"
	@echo "  test-integration - Tests d'intégration (lents)"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  configure        - Assistant interactif de configuration"
	@echo "  validate         - Valider la configuration Terraform"
	@echo "  plan             - Planifier les changements"
	@echo ""
	@echo "$(YELLOW)Déploiement:$(NC)"
	@echo "  deploy           - Déployer l'infrastructure complète"
	@echo "  deploy-custom    - Déployer avec terraform.tfvars personnalisé"
	@echo ""
	@echo "$(YELLOW)Déploiements individuels:$(NC)"
	@echo "  deploy-havoc     - Déployer uniquement Havoc C2"
	@echo "  deploy-sliver    - Déployer uniquement Sliver C2"
	@echo "  deploy-mythic    - Déployer uniquement Mythic C2"
	@echo "  deploy-empire    - Déployer uniquement Empire C2"
	@echo "  deploy-metasploit - Déployer uniquement Metasploit C2"
	@echo ""
	@echo "$(YELLOW)Déploiements combinés:$(NC)"
	@echo "  deploy-compare-havoc-sliver - Déployer Havoc et Sliver pour comparaison"
	@echo "  deploy-modern    - Déployer les frameworks modernes (Havoc, Sliver, Mythic)"
	@echo ""
	@echo "$(YELLOW)Destruction:$(NC)"
	@echo "  destroy          - Détruire l'infrastructure"
	@echo ""
	@echo "$(YELLOW)Développement:$(NC)"
	@echo "  fmt              - Formater le code"
	@echo "  clean            - Nettoyer les artefacts"
	@echo "  docker-build     - Construire les images Docker"

# Tests
test: test-unit test-integration ## Lancer tous les tests

test-unit: ## Tests unitaires (validation, plan)
	@echo "$(BLUE)[TDD]$(NC) Lancement des tests unitaires..."
	cd $(TESTS_DIR) && go test -v -run "TestTerraformValidation|TestTerraformPlan|TestDockerfiles|TestTerraformOutputs" ./...

test-integration: ## Tests d'intégration (déploiement complet)
	@echo "$(BLUE)[TDD]$(NC) Lancement des tests d'intégration..."
	@echo "$(YELLOW)⚠️  Attention: ces tests déploient une infrastructure réelle$(NC)"
	cd $(TESTS_DIR) && go test -v -run "TestC2(Infrastructure|ContainersHealth)" -timeout 30m ./...

# Terraform
validate: ## Valider la configuration Terraform
	@echo "$(BLUE)[TERRAFORM]$(NC) Validation..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init -backend=false
	cd $(TERRAFORM_DIR) && $(TF_BIN) validate
	@echo "$(GREEN)✅ Configuration Terraform valide$(NC)"

fmt: ## Formater le code Terraform
	@echo "$(BLUE)[TERRAFORM]$(NC) Formatage..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) fmt -recursive
	@echo "$(GREEN)✅ Code formaté$(NC)"

plan: validate ## Planifier les changements
	@echo "$(BLUE)[TERRAFORM]$(NC) Plan..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) plan

deploy: validate ## Déployer l'infrastructure complète
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve
	@echo "$(GREEN)🎉 Infrastructure déployée!$(NC)"

# Déploiements individuels par framework C2
deploy-havoc: validate ## Déployer uniquement Havoc C2
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement de Havoc C2..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=true" \
		-var="deploy_sliver=false" \
		-var="deploy_mythic=false" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)🗡️  Havoc C2 déployé! Interface: https://localhost:8443$(NC)"

deploy-sliver: validate ## Déployer uniquement Sliver C2
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement de Sliver C2..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=false" \
		-var="deploy_sliver=true" \
		-var="deploy_mythic=false" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)🐍 Sliver C2 déployé! CLI: docker exec -it sliver-c2 sliver$(NC)"

deploy-mythic: validate ## Déployer uniquement Mythic C2
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement de Mythic C2..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=false" \
		-var="deploy_sliver=false" \
		-var="deploy_mythic=true" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)🏛️  Mythic C2 déployé! Interface: https://localhost:7443$(NC)"

deploy-empire: validate ## Déployer uniquement Empire C2
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement d'Empire C2..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=false" \
		-var="deploy_sliver=false" \
		-var="deploy_mythic=false" \
		-var="deploy_empire=true" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)👑 Empire C2 déployé! Interface: http://localhost:5000$(NC)"

deploy-metasploit: validate ## Déployer uniquement Metasploit C2
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement de Metasploit C2..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=false" \
		-var="deploy_sliver=false" \
		-var="deploy_mythic=false" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=true"
	@echo "$(GREEN)💥 Metasploit C2 déployé! CLI: docker exec -it metasploit-c2 msfconsole$(NC)"

# Déploiement avec fichier de variables personnalisé
deploy-custom: validate ## Déployer avec un fichier terraform.tfvars personnalisé
	@if [ ! -f terraform/terraform.tfvars ]; then \
		echo "$(RED)❌ Fichier terraform/terraform.tfvars non trouvé!$(NC)"; \
		echo "$(YELLOW)💡 Copiez terraform/terraform.tfvars.example vers terraform/terraform.tfvars$(NC)"; \
		echo "$(YELLOW)💡 Ou lancez 'make configure' pour un assistant interactif$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement avec configuration personnalisée..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve
	@echo "$(GREEN)🎯 Infrastructure déployée selon votre configuration!$(NC)"

configure: ## Assistant interactif de configuration des frameworks
	@echo "$(BLUE)[CONFIG]$(NC) Lancement de l'assistant de configuration..."
	@./scripts/deploy-selector.sh

# Comparaison de configurations
deploy-compare-havoc-sliver: validate ## Déployer Havoc et Sliver pour comparaison
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement pour comparaison Havoc vs Sliver..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=true" \
		-var="deploy_sliver=true" \
		-var="deploy_mythic=false" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)⚔️  Havoc vs Sliver déployés pour comparaison!$(NC)"
	@echo "$(YELLOW)🗡️  Havoc: https://localhost:8443$(NC)"
	@echo "$(YELLOW)🐍 Sliver: docker exec -it sliver-c2 sliver$(NC)"

deploy-modern: validate ## Déployer les frameworks modernes (Havoc, Sliver, Mythic)
	@echo "$(BLUE)[TERRAFORM]$(NC) Déploiement des frameworks modernes..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	cd $(TERRAFORM_DIR) && $(TF_BIN) apply -auto-approve \
		-var="deploy_havoc=true" \
		-var="deploy_sliver=true" \
		-var="deploy_mythic=true" \
		-var="deploy_empire=false" \
		-var="deploy_metasploit=false"
	@echo "$(GREEN)🚀 Frameworks modernes déployés!$(NC)"

destroy: ## Détruire l'infrastructure
	@echo "$(RED)[TERRAFORM]$(NC) Destruction..."
	cd $(TERRAFORM_DIR) && $(TF_BIN) init -backend=false > /dev/null
	# Détruire toutes les ressources docker_container et docker_image individuellement pour éviter l'erreur prevent_destroy
	cd $(TERRAFORM_DIR) && $(TF_BIN) state list | grep -E "docker_(container|image)" | while read res; do \
		echo "$(YELLOW)→ destruction $$res$(NC)"; \
               $(TF_BIN) destroy -auto-approve -target=$$res > /dev/null; \
	done
	# Le réseau est protégé, on le supprime manuellement ensuite
	-docker network rm purple-team-net > /dev/null 2>&1 || true
	@echo "$(YELLOW)🧹 Infrastructure détruite$(NC)"

# Docker
docker-build: havoc-bin ## Construire toutes les images Docker (parallèle + cache BuildKit)
	@echo "$(BLUE)[DOCKER]$(NC) Construction des images (parallèle)..."
	# Construire/mettre à jour l'image de base Havoc (rarement modifiée)
	docker build --platform linux/amd64 -f $(DOCKER_DIR)/havoc/Dockerfile.base -t havoc-base:22.04 $(DOCKER_DIR)/havoc || exit 1
	@for framework in $(FRAMEWORKS); do \
		echo "$(BLUE)Building $$framework...$(NC)"; \
		if [ "$$framework" = "havoc" ]; then \
			docker build --platform linux/amd64 -t purple-team-havoc:latest $(DOCKER_DIR)/havoc || exit 1; \
		else \
			docker build --platform linux/amd64 -t purple-team-$$framework:latest $(DOCKER_DIR)/$$framework || exit 1; \
		fi; \
	done
	@echo "$(GREEN)✅ Toutes les images construites$(NC)"

docker-test: ## Tester les images Docker individuellement
	@echo "$(BLUE)[DOCKER]$(NC) Test des images..."
	@for framework in havoc sliver metasploit; do \
		echo "$(BLUE)Testing $$framework...$(NC)"; \
		docker run --rm --name test-$$framework -d purple-team-$$framework:latest || true; \
		sleep 5; \
		if docker ps | grep -q test-$$framework; then \
			echo "$(GREEN)✅ $$framework OK$(NC)"; \
			docker stop test-$$framework > /dev/null 2>&1 || true; \
		else \
			echo "$(RED)❌ $$framework FAILED$(NC)"; \
		fi; \
	done

# Nettoyage
clean: ## Nettoyer les artefacts
	@echo "$(BLUE)[CLEAN]$(NC) Nettoyage..."
	# Terraform
	cd $(TERRAFORM_DIR) && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
	# Go tests
	cd $(TESTS_DIR) && go clean -testcache
	# Docker
	docker system prune -f > /dev/null 2>&1 || true
	@echo "$(GREEN)🧹 Nettoyage terminé$(NC)"

# Workflow TDD complet
tdd: clean fmt validate test-unit docker-build deploy test-integration ## Workflow TDD complet

# CI/CD Pipeline
ci: fmt validate test-unit docker-build ## Pipeline CI (sans déploiement)
	@echo "$(GREEN)🎉 Pipeline CI terminée avec succès!$(NC)"

# Installation des dépendances
deps: ## Installer les dépendances
	@echo "$(BLUE)[DEPS]$(NC) Installation des dépendances..."
	# Go modules
	cd $(TESTS_DIR) && go mod download
	# Terraform providers
	cd $(TERRAFORM_DIR) && $(TF_BIN) init
	@echo "$(GREEN)✅ Dépendances installées$(NC)"

# Status du déploiement
status: ## Afficher le status de l'infrastructure
	@echo "$(BLUE)[STATUS]$(NC) Infrastructure actuelle:"
	@if [ -f $(TERRAFORM_DIR)/terraform.tfstate ]; then \
		cd $(TERRAFORM_DIR) && $(TF_BIN) show -json | jq -r '.values.root_module.resources[] | select(.type == "docker_container") | "Container: " + .values.name + " - Status: " + (.values.running | tostring)' 2>/dev/null || echo "Terraform state trouvé mais jq non disponible"; \
	else \
		echo "$(YELLOW)Aucune infrastructure déployée$(NC)"; \
	fi
	@echo ""
	@echo "$(BLUE)Containers Docker:$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(havoc|sliver|empire|metasploit)" || echo "Aucun container C2 en cours d'exécution"

# Générer le binaire Havoc (teamserver) en local si besoin
havoc-bin: ## Compiler le binaire Havoc teamserver en local (cache)
	@echo "$(BLUE)[HAVOC]$(NC) Compilation du binaire teamserver…"
	@mkdir -p $(DOCKER_DIR)/havoc/bin
	@if [ ! -f $(HAVOC_BIN) ]; then \
		echo "$(YELLOW)Téléchargement du code source Havoc…$(NC)"; \
		rm -rf /tmp/havoc-build && git clone --depth 1 https://github.com/HavocFramework/Havoc.git /tmp/havoc-build; \
		cd /tmp/havoc-build && make dev-ts-compile; \
		cp havoc $(CURDIR)/$(HAVOC_BIN) || { echo "$(RED)❌ Compil failed$(NC)"; exit 1; }; \
		cp -r profiles $(CURDIR)/$(DOCKER_DIR)/havoc/; \
		echo "$(GREEN)✅ Binaire Havoc compilé et copié$(NC)"; \
	else \
		echo "$(GREEN)✅ Binaire déjà présent : compilation sautée$(NC)"; \
	fi

# Docker remote registry helpers

docker-prune: ## Purge complète (images, volumes, builder cache)
	@echo "$(BLUE)[DOCKER]$(NC) Purge complète…"
	docker system prune -a --volumes -f | cat
	@echo "$(GREEN)✅ Docker propre$(NC)"

docker-pull: ## Tirer les images pré-construites depuis un registre
	@if [ -z "$(REGISTRY)" ]; then \
		printf "$(RED)REGISTRY non défini. Utilisez REGISTRY=<votre_registry> make docker-pull$(NC)\n"; exit 1; \
	fi
	@for framework in $(FRAMEWORKS); do \
		remote=$(REGISTRY)/purple-team-$$framework:latest; \
		echo "$(BLUE)Pull $$remote$(NC)"; \
		docker pull $$remote || exit 1; \
	done
	@echo "$(GREEN)✅ Images tirées avec succès$(NC)"

docker-push: ## Pousser les images locales vers un registre
	@if [ -z "$(REGISTRY)" ]; then \
		printf "$(RED)REGISTRY non défini. Utilisez REGISTRY=<votre_registry> make docker-push$(NC)\n"; exit 1; \
	fi
	@for framework in $(FRAMEWORKS); do \
		local=purple-team-$$framework:latest; \
		remote=$(REGISTRY)/$$local; \
		echo "$(BLUE)Tag & push $$local -> $$remote$(NC)"; \
		docker tag $$local $$remote && docker push $$remote || exit 1; \
	done
	@echo "$(GREEN)✅ Images publiées$(NC)" 