# Exemple de fichier terraform.tfvars pour C2-Dploy
# Copiez ce fichier vers terraform.tfvars et modifiez selon vos besoins

# Configuration de déploiement des frameworks C2
# Définir à true pour déployer, false pour ignorer

deploy_havoc      = true   # Framework Havoc C2 (moderne, évasion avancée)
deploy_sliver     = true   # Framework Sliver C2 (Go, cross-platform)
deploy_mythic     = true   # Framework Mythic C2 (conteneur complet)
deploy_empire     = true   # Framework Empire C2 (PowerShell)
deploy_metasploit = true   # Framework Metasploit (classique)

# Configuration environnement
environment = "dev"  # dev, test, prod

# Configuration réseau
network_subnet = "172.20.0.0/16"

# Domaine de base (optionnel)
base_domain = "localhost"

# Mot de passe par défaut pour tous les C2
# CHANGEZ CETTE VALEUR EN PRODUCTION !
default_password = "PurpleTeam2024!"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Exemples de configurations courantes :
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Configuration 1: Seulement Havoc pour tests rapides
# deploy_havoc      = true
# deploy_sliver     = false
# deploy_mythic     = false
# deploy_empire     = false
# deploy_metasploit = false

# Configuration 2: Frameworks modernes uniquement
# deploy_havoc      = true
# deploy_sliver     = true
# deploy_mythic     = true
# deploy_empire     = false
# deploy_metasploit = false

# Configuration 3: Comparaison Havoc vs Sliver
# deploy_havoc      = true
# deploy_sliver     = true
# deploy_mythic     = false
# deploy_empire     = false
# deploy_metasploit = false 