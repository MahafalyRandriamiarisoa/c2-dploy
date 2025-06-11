terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {}

# Création des dossiers de données locaux (conditionnel)
locals {
  enabled_frameworks = {
    for framework in ["havoc", "sliver", "mythic", "empire", "metasploit"] : 
    framework => lookup({
      "havoc"      = var.deploy_havoc
      "sliver"     = var.deploy_sliver  
      "mythic"     = var.deploy_mythic
      "empire"     = var.deploy_empire
      "metasploit" = var.deploy_metasploit
    }, framework, false)
  }
  
  active_frameworks = [for k, v in local.enabled_frameworks : k if v]
}

resource "local_file" "data_dirs" {
  for_each = toset(local.active_frameworks)

  content  = ""
  filename = "${path.cwd}/data/${each.key}/.gitkeep"

  provisioner "local-exec" {
    command = "mkdir -p ${path.cwd}/data/${each.key}"
  }
}

# Dossier payloads
resource "local_file" "payloads_dir" {
  content  = ""
  filename = "${path.cwd}/payloads/.gitkeep"

  provisioner "local-exec" {
    command = "mkdir -p ${path.cwd}/payloads"
  }
}

# Réseau Docker pour les C2
resource "docker_network" "purple_team_network" {
  name   = "purple-team-net"
  driver = "bridge"

  # Si le réseau existe déjà, Docker renverra son ID et Terraform l'utilisera
  # plutôt que d'échouer (équivalent d'un import implicite)
  check_duplicate = true

  # Empêche Terraform de détruire ce réseau (utile quand d'autres containers
  # externes y sont connectés) et ignore d'éventuelles modifications hors TF.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [driver, ipam_config]
  }

  ipam_config {
    subnet = "172.20.0.0/16"
  }
}

# Container Havoc C2
resource "docker_container" "havoc_c2" {
  count = var.deploy_havoc ? 1 : 0
  
  name  = "havoc-c2"
  image = docker_image.havoc[0].image_id

  depends_on = [local_file.data_dirs]

  ports {
    internal = 40056
    external = 40056
  }

  ports {
    internal = 443
    external = 8443
  }

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.10"
  }

  volumes {
    container_path = "/opt/havoc/data"
    host_path      = "${path.cwd}/data/havoc"
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:40056"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Container Sliver C2
resource "docker_container" "sliver_c2" {
  count = var.deploy_sliver ? 1 : 0
  
  name  = "sliver-c2"
  image = docker_image.sliver[0].image_id

  depends_on = [local_file.data_dirs]

  ports {
    internal = 31337
    external = 31337
  }

  ports {
    internal = 443
    external = 9443
  }

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.20"
  }

  volumes {
    container_path = "/root/.sliver"
    host_path      = "${path.cwd}/data/sliver"
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:31337"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# ── Mythic écosystème officiel ─────────────────────────────

# RabbitMQ (broker)
resource "docker_container" "mythic_rabbitmq" {
  count = var.deploy_mythic ? 1 : 0
  
  name  = "mythic-rabbitmq"
  image = docker_image.mythic_rabbitmq[0].name

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.31"
  }

  env = [
    "RABBITMQ_DEFAULT_USER=mythic",
    "RABBITMQ_DEFAULT_PASS=mythicpassword"
  ]

  healthcheck {
    test     = ["CMD-SHELL", "rabbitmq-diagnostics -q ping"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Postgres (DB)
resource "docker_container" "mythic_postgres" {
  count = var.deploy_mythic ? 1 : 0
  
  name  = "mythic-postgres"
  image = docker_image.mythic_postgres[0].name

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.32"
  }

  env = [
    "POSTGRES_USER=mythic",
    "POSTGRES_PASSWORD=mythicpassword",
    "POSTGRES_DB=mythic"
  ]

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U mythic"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Core Mythic server (API, workers)
resource "docker_container" "mythic_server" {
  count = var.deploy_mythic ? 1 : 0
  
  name  = "mythic-server"
  image = docker_image.mythic_server[0].name

  depends_on = [docker_container.mythic_rabbitmq, docker_container.mythic_postgres]

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.30"
  }

  env = [
    "MYTHIC_RABBITMQ_HOST=172.20.0.31",
    "MYTHIC_RABBITMQ_USER=mythic",
    "MYTHIC_RABBITMQ_PASSWORD=mythicpassword",
    "MYTHIC_POSTGRES_HOST=172.20.0.32",
    "MYTHIC_POSTGRES_USER=mythic",
    "MYTHIC_POSTGRES_PASSWORD=mythicpassword",
    "MYTHIC_POSTGRES_DB=mythic"
  ]
}

# NGINX front-end (UI, SSL termination)
resource "docker_container" "mythic_react" {
  count = var.deploy_mythic ? 1 : 0
  
  name  = "mythic-react"
  image = docker_image.mythic_react[0].name

  depends_on = [docker_container.mythic_server]

  ports {
    internal = 7443
    external = 7443
  }

  ports {
    internal = 17443
    external = 17443
  }

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.33"
  }

  env = [
    "MYTHIC_SERVER_HOST=172.20.0.30"
  ]

  healthcheck {
    test     = ["CMD", "curl", "-k", "-f", "https://localhost:7443"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Container Empire C2
resource "docker_container" "empire_c2" {
  count = var.deploy_empire ? 1 : 0
  
  name  = "empire-c2"
  image = docker_image.empire[0].image_id

  depends_on = [local_file.data_dirs]

  ports {
    internal = 1337
    external = 1337
  }

  ports {
    internal = 5000
    external = 5000
  }

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.40"
  }

  volumes {
    container_path = "/empire/data"
    host_path      = "${path.cwd}/data/empire"
  }

  working_dir = "/empire"

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:5000"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Container Metasploit
resource "docker_container" "metasploit_c2" {
  count = var.deploy_metasploit ? 1 : 0
  
  name  = "metasploit-c2"
  image = docker_image.metasploit[0].image_id

  depends_on = [local_file.data_dirs]

  ports {
    internal = 4444
    external = 4444
  }

  ports {
    internal = 8080
    external = 8080
  }

  networks_advanced {
    name         = docker_network.purple_team_network.name
    ipv4_address = "172.20.0.50"
  }

  volumes {
    container_path = "/root/.msf4"
    host_path      = "${path.cwd}/data/metasploit"
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Script de génération de payloads automatique
resource "local_file" "payload_generator" {
  content = templatefile("${path.module}/templates/generate-payloads.sh", {
    containers = {
      havoc      = "172.20.0.10"
      sliver     = "172.20.0.20"
      mythic     = "172.20.0.30"
      empire     = "172.20.0.40"
      metasploit = "172.20.0.50"
    }
    enabled_frameworks = local.enabled_frameworks
  })
  filename = "${path.cwd}/payloads/generate-all.sh"

  # Dépendance simplifiée - sera créé même si aucun container n'est déployé
  depends_on = [local_file.data_dirs]

  provisioner "local-exec" {
    command = "chmod +x ${path.cwd}/payloads/generate-all.sh"
  }
} 