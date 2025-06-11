# Outputs pour afficher les informations des C2 déployés

output "purple_team_summary" {
  value = {
    network = docker_network.purple_team_network.name
    containers = {
      havoc = {
        name      = docker_container.havoc_c2.name
        ip        = "172.20.0.10"
        ports     = ["40056", "8443"]
        interface = "https://localhost:8443"
      }
      sliver = {
        name      = docker_container.sliver_c2.name
        ip        = "172.20.0.20"
        ports     = ["31337", "9443"]
        interface = "CLI: docker exec -it sliver-c2 sliver"
      }
      mythic = {
        name      = docker_container.mythic_react.name
        ip        = "172.20.0.33"
        ports     = ["7443", "17443"]
        interface = "https://localhost:7443"
      }
      empire = {
        name      = docker_container.empire_c2.name
        ip        = "172.20.0.40"
        ports     = ["1337", "5000"]
        interface = "http://localhost:5000"
      }
      metasploit = {
        name      = docker_container.metasploit_c2.name
        ip        = "172.20.0.50"
        ports     = ["4444", "8080"]
        interface = "CLI: docker exec -it metasploit-c2 msfconsole"
      }
    }
  }
}

output "credentials" {
  value = {
    mythic_admin            = "mythic_admin"
    mythic_password         = "PurpleTeam2024!"
    empire_password         = "PurpleTeam2024!"
    metasploit_rpc_password = "PurpleTeam2024!"
  }
  sensitive = true
}

output "payload_directory" {
  value = "${path.cwd}/payloads/"
} 