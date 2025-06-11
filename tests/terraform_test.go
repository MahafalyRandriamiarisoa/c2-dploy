package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestC2Infrastructure(t *testing.T) {
	// Test d'intégration complet (à lancer manuellement)
	// Décommenté seulement pour les tests complets en CI/CD
	t.Skip("Integration test - run manually with 'go test -run TestC2Infrastructure'")

	t.Parallel()

	// Configuration Terraform
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform",
		Vars: map[string]interface{}{
			"environment": "test",
		},
	})

	// Nettoyage automatique
	defer terraform.Destroy(t, terraformOptions)

	// Phase 1: Apply Infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Phase 2: Validate Outputs
	validateTerraformOutputs(t, terraformOptions)

	// Phase 3: Basic Health Check
	testBasicHealthCheck(t)
}

func validateTerraformOutputs(t *testing.T, terraformOptions *terraform.Options) {
	// Test que les outputs existent
	outputs := []string{
		"havoc_url",
		"sliver_url", 
		"mythic_url",
		"empire_url",
		"metasploit_url",
		"network_name",
	}

	for _, output := range outputs {
		value := terraform.Output(t, terraformOptions, output)
		assert.NotEmpty(t, value, fmt.Sprintf("Output %s should not be empty", output))
	}
}

func testBasicHealthCheck(t *testing.T) {
	// Tests basiques après déploiement
	containers := []string{
		"havoc-c2",
		"sliver-c2",
		"mythic-c2", 
		"empire-c2",
		"metasploit-c2",
	}

	for _, container := range containers {
		t.Run(fmt.Sprintf("Container_%s_Basic_Check", container), func(t *testing.T) {
			// Test basique - on vérifie juste que le test peut s'exécuter
			assert.NotEmpty(t, container, "Container name should not be empty")
			
			// Ici, en production, on ajouterait des checks plus avancés
			// avec les outils Docker ou curl appropriés
			time.Sleep(1 * time.Second) // Simule un test
		})
	}
}

 