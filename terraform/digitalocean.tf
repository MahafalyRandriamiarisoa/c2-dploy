terraform {
  required_version = ">= 1.4"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.33.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token != "" ? var.do_token : (try(env("DIGITALOCEAN_TOKEN"), ""))
}

# Droplet unique hébergeant tous les conteneurs C2 via Docker Compose
resource "digitalocean_droplet" "c2_droplet" {
  count  = var.deploy_on_digitalocean ? 1 : 0
  name   = "c2-dploy-${var.environment}"
  region = var.do_region
  size   = var.do_size
  image  = "docker-20-04"

  ssh_keys = var.do_ssh_key_ids

  # Cloud-Init script : installe Docker + compose & lance les conteneurs
  user_data = <<-EOF
    #cloud-config
    package_update: true
    packages:
      - docker.io
      - docker-compose
    runcmd:
      - systemctl enable --now docker
      - docker network create purple-team-net || true
      # Exemple : ne lancer que Sliver par défaut (adaptable)
      - docker run -d --name sliver-c2 --network purple-team-net ghcr.io/bishopfox/sliver || true
  EOF
}

output "digitalocean_droplet_ip" {
  value       = var.deploy_on_digitalocean ? digitalocean_droplet.c2_droplet[0].ipv4_address : ""
  description = "Adresse IP publique du droplet hébergeant les C2 (si déploiement DigitalOcean activé)"
} 