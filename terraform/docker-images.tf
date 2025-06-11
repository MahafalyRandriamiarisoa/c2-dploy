# Images Docker pour les C2

# Image Havoc C2
resource "docker_image" "havoc" {
  name = "havoc-c2:latest"
  build {
    context    = "../docker/havoc"
    dockerfile = "Dockerfile"
    cache_from = ["havoc-c2:latest"]
  }
}

# Image Sliver C2
resource "docker_image" "sliver" {
  name = "sliver-c2:latest"
  build {
    context    = "../docker/sliver"
    dockerfile = "Dockerfile"
    cache_from = ["sliver-c2:latest"]
  }
}

# Images Mythic officielles (Docker Hub)
resource "docker_image" "mythic_server" {
  name = "itsafeaturemythic/mythic_server:0.0.5"
}

resource "docker_image" "mythic_rabbitmq" {
  name = "itsafeaturemythic/mythic_rabbitmq:0.0.3"
}

resource "docker_image" "mythic_postgres" {
  name = "itsafeaturemythic/mythic_postgres:0.0.2"
}

# UI React front-end
resource "docker_image" "mythic_react" {
  name = "itsafeaturemythic/mythic_react:0.0.6"
}

# Image Empire C2 (officielle Docker Hub)
resource "docker_image" "empire" {
  name = "bcsecurity/empire:latest"
}

# Image Metasploit
resource "docker_image" "metasploit" {
  name = "metasploit-c2:latest"
  build {
    context    = "../docker/metasploit"
    dockerfile = "Dockerfile"
    cache_from = ["metasploit-c2:latest"]
  }
} 