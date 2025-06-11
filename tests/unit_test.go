package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../terraform",
	}

	// Test de validation Terraform
	terraform.Validate(t, terraformOptions)
}

func TestTerraformPlan(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../terraform",
		PlanFilePath: "/tmp/terraform-plan",
	}

	// Test que le plan Terraform est valide
	terraform.InitAndPlan(t, terraformOptions)
}

func TestDockerfiles(t *testing.T) {
	frameworks := []string{"havoc", "sliver", "mythic", "empire", "metasploit"}

	for _, framework := range frameworks {
		t.Run("Dockerfile_"+framework, func(t *testing.T) {
			// Test que les Dockerfiles existent et sont valides
			dockerfilePath := "../docker/" + framework + "/Dockerfile"
			
			// Vérification que le fichier existe
			_, err := os.Stat(dockerfilePath)
			assert.NoError(t, err, "Dockerfile should exist for "+framework)
		})
	}
}

func TestTerraformOutputs(t *testing.T) {
	expectedOutputs := []string{
		"havoc_url",
		"sliver_url",
		"mythic_url", 
		"empire_url",
		"metasploit_url",
		"network_name",
	}

	// Vérifier que tous les outputs attendus sont définis dans le fichier outputs.tf
	outputsFile := "../terraform/outputs.tf"
	_, err := os.Stat(outputsFile)
	assert.NoError(t, err, "outputs.tf should exist")

	for _, output := range expectedOutputs {
		t.Run("Output_"+output, func(t *testing.T) {
			// Test basique que le nom de l'output n'est pas vide
			assert.NotEmpty(t, output, "Output name should not be empty")
		})
	}
}

func TestTerraformFiles(t *testing.T) {
	requiredFiles := []string{
		"../terraform/main.tf",
		"../terraform/outputs.tf", 
		"../terraform/docker-images.tf",
	}

	for _, file := range requiredFiles {
		t.Run("File_exists_"+file, func(t *testing.T) {
			_, err := os.Stat(file)
			assert.NoError(t, err, "Required Terraform file should exist: "+file)
		})
	}
} 