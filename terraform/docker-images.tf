# Images Docker pour les C2 (conditionnelles)

# Image Havoc C2
resource "docker_image" "havoc" {
  count        = var.deploy_havoc ? 1 : 0
  name         = "purple-team-havoc:latest"
  keep_locally = true
}

# Image Sliver C2
resource "docker_image" "sliver" {
  count = var.deploy_sliver ? 1 : 0
  name  = "sliver-c2:latest"
  build {
    context    = "../docker/sliver"
    dockerfile = "Dockerfile"
    cache_from = ["sliver-c2:latest"]
  }
}

# Images Mythic officielles (Docker Hub)
resource "docker_image" "mythic_server" {
  count    = var.deploy_mythic ? 1 : 0
  name     = "itsafeaturemythic/mythic_server:0.0.4"
  platform = "linux/amd64"
}

resource "docker_image" "mythic_rabbitmq" {
  count    = var.deploy_mythic ? 1 : 0
  name     = "itsafeaturemythic/mythic_rabbitmq:0.0.3"
  platform = "linux/amd64"
}

resource "docker_image" "mythic_postgres" {
  count    = var.deploy_mythic ? 1 : 0
  name     = "itsafeaturemythic/mythic_postgres:0.0.2"
  platform = "linux/amd64"
}

# UI React front-end
resource "docker_image" "mythic_react" {
  count    = var.deploy_mythic ? 1 : 0
  name     = "itsafeaturemythic/mythic_react:0.0.6"
  platform = "linux/amd64"
}

# Image Empire C2 (officielle Docker Hub)
resource "docker_image" "empire" {
  count    = var.deploy_empire ? 1 : 0
  name     = "bcsecurity/empire:latest"
  platform = "linux/amd64"
}

# Image Metasploit
resource "docker_image" "metasploit" {
  count = var.deploy_metasploit ? 1 : 0
  name  = "metasploit-c2:latest"
  build {
    context    = "../docker/metasploit"
    dockerfile = "Dockerfile"
    cache_from = ["metasploit-c2:latest"]
  }
} 