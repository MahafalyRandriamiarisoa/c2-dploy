# Outputs pour afficher les informations des C2 déployés (conditionnels)

output "purple_team_summary" {
  value = {
    network = docker_network.purple_team_network.name
    containers = merge(
      var.deploy_havoc ? {
        havoc = {
          name      = docker_container.havoc_c2[0].name
          ip        = "172.20.0.10"
          ports     = ["40056", "8443"]
          interface = "https://localhost:8443"
          status    = "deployed"
        }
      } : {},
      var.deploy_sliver ? {
        sliver = {
          name      = docker_container.sliver_c2[0].name
          ip        = "172.20.0.20"
          ports     = ["31337", "9443"]
          interface = "CLI: docker exec -it sliver-c2 sliver"
          status    = "deployed"
        }
      } : {},
      var.deploy_mythic ? {
        mythic = {
          name      = docker_container.mythic_react[0].name
          ip        = "172.20.0.33"
          ports     = ["7443", "17443"]
          interface = "https://localhost:7443"
          status    = "deployed"
        }
      } : {},
      var.deploy_empire ? {
        empire = {
          name      = docker_container.empire_c2[0].name
          ip        = "172.20.0.40"
          ports     = ["1337", "5000"]
          interface = "http://localhost:5000"
          status    = "deployed"
        }
      } : {},
      var.deploy_metasploit ? {
        metasploit = {
          name      = docker_container.metasploit_c2[0].name
          ip        = "172.20.0.50"
          ports     = ["4444", "8080"]
          interface = "CLI: docker exec -it metasploit-c2 msfconsole"
          status    = "deployed"
        }
      } : {}
    )
    environment = var.environment
    active_frameworks = local.active_frameworks
  }
}

output "deployment_configuration" {
  value = {
    havoc      = var.deploy_havoc
    sliver     = var.deploy_sliver
    mythic     = var.deploy_mythic
    empire     = var.deploy_empire
    metasploit = var.deploy_metasploit
  }
  description = "Configuration de déploiement des frameworks"
}

output "credentials" {
  value = merge(
    var.deploy_mythic ? {
      mythic_admin    = "mythic_admin"
      mythic_password = var.default_password
    } : {},
    var.deploy_empire ? {
      empire_password = var.default_password
    } : {},
    var.deploy_metasploit ? {
      metasploit_rpc_password = var.default_password
    } : {},
    var.deploy_havoc ? {
      havoc_admin_password = var.default_password
    } : {}
  )
  sensitive = true
}

output "payload_directory" {
  value = "${path.cwd}/payloads/"
} 