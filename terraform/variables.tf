# Variables pour le déploiement sélectif des frameworks C2

variable "deploy_havoc" {
  description = "Déployer le framework Havoc C2"
  type        = bool
  default     = true
}

variable "deploy_sliver" {
  description = "Déployer le framework Sliver C2"
  type        = bool
  default     = true
}

variable "deploy_mythic" {
  description = "Déployer le framework Mythic C2"
  type        = bool
  default     = true
}

variable "deploy_empire" {
  description = "Déployer le framework Empire C2"
  type        = bool
  default     = true
}

variable "deploy_metasploit" {
  description = "Déployer le framework Metasploit C2"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Nom de l'environnement (dev, prod, test)"
  type        = string
  default     = "dev"
}

# Variables de configuration globale
variable "network_subnet" {
  description = "Subnet pour le réseau Docker"
  type        = string
  default     = "172.20.0.0/16"
}

variable "base_domain" {
  description = "Domaine de base pour les C2 (optionnel)"
  type        = string
  default     = "localhost"
}

# Credentials par défaut
variable "default_password" {
  description = "Mot de passe par défaut pour les C2"
  type        = string
  default     = "PurpleTeam2024!"
  sensitive   = true
} 