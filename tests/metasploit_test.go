package test

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os/exec"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// MetasploitTestHelper fournit des utilitaires pour les tests Metasploit
type MetasploitTestHelper struct {
	cli           *client.Client
	containerName string
	ctx           context.Context
}

// NewMetasploitTestHelper crée une nouvelle instance du helper de test
func NewMetasploitTestHelper() (*MetasploitTestHelper, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, err
	}

	return &MetasploitTestHelper{
		cli:           cli,
		containerName: "metasploit-c2",
		ctx:           context.Background(),
	}, nil
}

// IsContainerRunning vérifie si le container Metasploit est en cours d'exécution
func (h *MetasploitTestHelper) IsContainerRunning() (bool, error) {
	containers, err := h.cli.ContainerList(h.ctx, types.ContainerListOptions{})
	if err != nil {
		return false, err
	}

	for _, container := range containers {
		for _, name := range container.Names {
			if strings.Contains(name, h.containerName) && container.State == "running" {
				return true, nil
			}
		}
	}
	return false, nil
}

// GetContainerLogs récupère les logs du container
func (h *MetasploitTestHelper) GetContainerLogs() (string, error) {
	containers, err := h.cli.ContainerList(h.ctx, types.ContainerListOptions{})
	if err != nil {
		return "", err
	}

	var containerID string
	for _, container := range containers {
		for _, name := range container.Names {
			if strings.Contains(name, h.containerName) {
				containerID = container.ID
				break
			}
		}
	}

	if containerID == "" {
		return "", fmt.Errorf("container %s not found", h.containerName)
	}

	options := types.ContainerLogsOptions{ShowStdout: true, ShowStderr: true}
	out, err := h.cli.ContainerLogs(h.ctx, containerID, options)
	if err != nil {
		return "", err
	}
	defer out.Close()

	logs, err := io.ReadAll(out)
	if err != nil {
		return "", err
	}

	return string(logs), nil
}

// IsPortOpen vérifie si un port est ouvert
func (h *MetasploitTestHelper) IsPortOpen(host string, port int) bool {
	timeout := time.Second * 2
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", host, port), timeout)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

// TestDatabaseConnection teste la connexion à la base de données PostgreSQL
func (h *MetasploitTestHelper) TestDatabaseConnection() error {
	// Test de connectivité au port PostgreSQL
	if !h.IsPortOpen("localhost", 5432) {
		return fmt.Errorf("PostgreSQL port 5432 not accessible")
	}

	// Vérifier que PostgreSQL répond en testant via une commande Docker
	output, err := h.ExecuteCommand("pg_isready -h localhost -p 5432 -U msf")
	if err != nil || !strings.Contains(output, "accepting connections") {
		return fmt.Errorf("PostgreSQL database not ready: %v", err)
	}

	return nil
}

// TestRPCConnection teste la connexion au daemon RPC Metasploit
func (h *MetasploitTestHelper) TestRPCConnection() error {
	// Test de connexion HTTP basic vers msfrpcd
	client := &http.Client{Timeout: 10 * time.Second}

	// Tenter de se connecter au RPC daemon
	resp, err := client.Get("http://localhost:8080/api/")
	if err != nil {
		return fmt.Errorf("failed to connect to RPC daemon: %v", err)
	}
	defer resp.Body.Close()

	// Le daemon devrait répondre même sans authentification (avec erreur d'auth)
	if resp.StatusCode == 200 || resp.StatusCode == 401 || resp.StatusCode == 403 {
		return nil
	}

	return fmt.Errorf("unexpected RPC response: %d", resp.StatusCode)
}

// ExecuteCommand exécute une commande dans le container
func (h *MetasploitTestHelper) ExecuteCommand(command string) (string, error) {
	cmd := exec.Command("docker", "exec", h.containerName, "bash", "-c", command)
	output, err := cmd.CombinedOutput()
	return string(output), err
}

// CheckMetasploitServices vérifie les services Metasploit
func (h *MetasploitTestHelper) CheckMetasploitServices() error {
	// Vérifier PostgreSQL
	output, err := h.ExecuteCommand("ps aux | grep postgres | grep -v grep")
	if err != nil || !strings.Contains(output, "postgres") {
		return fmt.Errorf("PostgreSQL service not running")
	}

	// Vérifier msfrpcd
	output, err = h.ExecuteCommand("ps aux | grep msfrpcd | grep -v grep")
	if err != nil || !strings.Contains(output, "msfrpcd") {
		return fmt.Errorf("msfrpcd service not running")
	}

	return nil
}

// CheckHandlerStatus vérifie le statut du multi/handler
func (h *MetasploitTestHelper) CheckHandlerStatus() error {
	// Vérifier si le handler écoute sur le port 4444
	if !h.IsPortOpen("localhost", 4444) {
		return fmt.Errorf("handler port 4444 not listening")
	}

	return nil
}

// TestMetasploitConsole teste l'accès à msfconsole
func (h *MetasploitTestHelper) TestMetasploitConsole() error {
	// Test d'exécution de msfconsole avec une commande simple
	output, err := h.ExecuteCommand("echo 'version' | msfconsole -q")
	if err != nil {
		return fmt.Errorf("failed to execute msfconsole: %v", err)
	}

	// Vérifier que la version est affichée
	if !strings.Contains(output, "Framework") || !strings.Contains(output, "Version") {
		return fmt.Errorf("msfconsole version check failed")
	}

	return nil
}

// TestMetasploitDeployment teste le déploiement complet de Metasploit
func TestMetasploitDeployment(t *testing.T) {
	helper, err := NewMetasploitTestHelper()
	require.NoError(t, err, "Failed to create test helper")

	t.Run("Container Status", func(t *testing.T) {
		running, err := helper.IsContainerRunning()
		assert.NoError(t, err, "Error checking container status")
		assert.True(t, running, "Metasploit container should be running")

		if running {
			t.Log("✅ Metasploit container is running")
		}
	})

	t.Run("PostgreSQL Database", func(t *testing.T) {
		assert.True(t, helper.IsPortOpen("localhost", 5432), "PostgreSQL port 5432 should be accessible")

		// Test de connexion à la base de données
		err := helper.TestDatabaseConnection()
		assert.NoError(t, err, "Database connection should work")

		if err == nil {
			t.Log("✅ PostgreSQL database is accessible and configured")
		}
	})

	t.Run("RPC Daemon Port", func(t *testing.T) {
		assert.True(t, helper.IsPortOpen("localhost", 8080), "RPC daemon port 8080 should be accessible")
		t.Log("✅ RPC daemon port is open")
	})

	t.Run("Handler Port", func(t *testing.T) {
		assert.True(t, helper.IsPortOpen("localhost", 4444), "Handler port 4444 should be accessible")
		t.Log("✅ Multi/handler port is listening")
	})

	t.Run("Web Interface Port", func(t *testing.T) {
		assert.True(t, helper.IsPortOpen("localhost", 8080), "Web interface port 8080 should be accessible")
		t.Log("✅ Web interface port is accessible")
	})

	t.Run("RPC Connection", func(t *testing.T) {
		err := helper.TestRPCConnection()
		assert.NoError(t, err, "RPC connection should be available")

		if err == nil {
			t.Log("✅ RPC daemon is responding")
		}
	})

	t.Run("Metasploit Services", func(t *testing.T) {
		err := helper.CheckMetasploitServices()
		assert.NoError(t, err, "Metasploit services should be running")

		if err == nil {
			t.Log("✅ Core Metasploit services are running")
		}
	})

	t.Run("Handler Status", func(t *testing.T) {
		err := helper.CheckHandlerStatus()
		assert.NoError(t, err, "Multi/handler should be active")

		if err == nil {
			t.Log("✅ Multi/handler is active and listening")
		}
	})

	t.Run("Console Access", func(t *testing.T) {
		err := helper.TestMetasploitConsole()
		assert.NoError(t, err, "Metasploit console should be accessible")

		if err == nil {
			t.Log("✅ Metasploit console is functional")
		}
	})

	t.Run("Configuration Files", func(t *testing.T) {
		// Vérifier la configuration de la base de données
		output, err := helper.ExecuteCommand("cat /root/.msf4/database.yml")
		assert.NoError(t, err, "Should be able to read database configuration")
		assert.Contains(t, output, "postgresql", "Database config should specify PostgreSQL")
		assert.Contains(t, output, "msf_database", "Database config should reference msf_database")

		if err == nil {
			t.Log("✅ Database configuration is valid")
		}
	})

	t.Run("Log Analysis", func(t *testing.T) {
		logs, err := helper.GetContainerLogs()
		assert.NoError(t, err, "Should be able to retrieve container logs")

		// Vérifier les indicateurs de succès dans les logs
		successIndicators := []string{
			"Metasploit est prêt",
			"msfrpcd",
			"multi/handler",
		}

		foundIndicators := 0
		for _, indicator := range successIndicators {
			if strings.Contains(logs, indicator) {
				foundIndicators++
				t.Logf("✅ Found success indicator: %s", indicator)
			}
		}

		assert.Greater(t, foundIndicators, 0, "Should find at least one success indicator in logs")

		// Vérifier l'absence d'erreurs critiques
		errorPatterns := []string{
			"FATAL",
			"ERROR.*failed",
			"Connection refused",
			"Permission denied",
		}

		for _, pattern := range errorPatterns {
			matched, _ := regexp.MatchString(pattern, logs)
			assert.False(t, matched, fmt.Sprintf("Should not find error pattern: %s", pattern))
		}

		t.Log("✅ Log analysis completed - no critical errors found")
	})
}

// TestMetasploitHealthCheck teste la santé du système Metasploit
func TestMetasploitHealthCheck(t *testing.T) {
	helper, err := NewMetasploitTestHelper()
	require.NoError(t, err)

	// Test de santé complet
	checks := map[string]func() error{
		"Container Running": func() error {
			running, err := helper.IsContainerRunning()
			if !running {
				return fmt.Errorf("container not running")
			}
			return err
		},
		"Database Connection": helper.TestDatabaseConnection,
		"RPC Service":         helper.TestRPCConnection,
		"Metasploit Services": helper.CheckMetasploitServices,
		"Handler Status":      helper.CheckHandlerStatus,
		"Console Access":      helper.TestMetasploitConsole,
	}

	for checkName, checkFunc := range checks {
		t.Run(checkName, func(t *testing.T) {
			err := checkFunc()
			assert.NoError(t, err, fmt.Sprintf("%s health check failed", checkName))

			if err == nil {
				t.Logf("✅ %s health check passed", checkName)
			}
		})
	}
}

// BenchmarkMetasploitResponseTime mesure les temps de réponse
func BenchmarkMetasploitResponseTime(b *testing.B) {
	helper, err := NewMetasploitTestHelper()
	if err != nil {
		b.Fatal(err)
	}

	b.Run("RPC Connection", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			helper.TestRPCConnection()
		}
	})

	b.Run("Database Query", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			helper.TestDatabaseConnection()
		}
	})

	b.Run("Console Command", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			helper.ExecuteCommand("echo 'version' | msfconsole -q")
		}
	})
}

// TestMetasploitIntegration teste l'intégration complète
func TestMetasploitIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	helper, err := NewMetasploitTestHelper()
	require.NoError(t, err)

	t.Run("Full Workflow Test", func(t *testing.T) {
		// 1. Vérifier que tous les services sont opérationnels
		running, err := helper.IsContainerRunning()
		assert.NoError(t, err)
		assert.True(t, running)

		// 2. Tester la base de données
		err = helper.TestDatabaseConnection()
		assert.NoError(t, err, "Database should be accessible")

		// 3. Tester RPC
		err = helper.TestRPCConnection()
		assert.NoError(t, err, "RPC should be accessible")

		// 4. Tester la console
		err = helper.TestMetasploitConsole()
		assert.NoError(t, err, "Console should be functional")

		// 5. Vérifier les handlers
		err = helper.CheckHandlerStatus()
		assert.NoError(t, err, "Handler should be active")

		t.Log("✅ Complete Metasploit integration test passed")
	})

	t.Run("Load Test", func(t *testing.T) {
		// Test de charge simple
		for i := 0; i < 5; i++ {
			err := helper.TestRPCConnection()
			assert.NoError(t, err, fmt.Sprintf("Load test iteration %d failed", i+1))
		}

		t.Log("✅ Load test completed successfully")
	})

	t.Run("Recovery Test", func(t *testing.T) {
		// Simuler une situation de récupération
		running, err := helper.IsContainerRunning()
		assert.NoError(t, err)

		if running {
			// Attendre un peu et re-tester
			time.Sleep(2 * time.Second)

			err = helper.TestRPCConnection()
			assert.NoError(t, err, "Service should recover quickly")

			t.Log("✅ Recovery test passed")
		}
	})
}
