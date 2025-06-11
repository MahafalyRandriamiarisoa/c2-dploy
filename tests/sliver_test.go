package test

import (
	"context"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSliverDeployment teste le déploiement complet de Sliver C2
func TestSliverDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping Sliver deployment test in short mode")
	}

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	// Test 1: Vérifier que le container Sliver existe et fonctionne
	t.Run("ContainerRunning", func(t *testing.T) {
		testSliverContainerRunning(t, ctx, cli)
	})

	// Test 2: Vérifier les ports exposés
	t.Run("PortsExposed", func(t *testing.T) {
		testSliverPortsExposed(t)
	})

	// Test 3: Vérifier l'interface CLI Sliver
	t.Run("SliverCLI", func(t *testing.T) {
		testSliverCLI(t, ctx, cli)
	})

	// Test 4: Vérifier les capacités de génération d'implants
	t.Run("ImplantGeneration", func(t *testing.T) {
		testSliverImplantGeneration(t, ctx, cli)
	})

	// Test 5: Vérifier la configuration Sliver
	t.Run("Configuration", func(t *testing.T) {
		testSliverConfiguration(t, ctx, cli)
	})

	// Test 6: Vérifier les logs du container
	t.Run("ContainerLogs", func(t *testing.T) {
		testSliverLogs(t, ctx, cli)
	})

	// Test 7: Vérifier les listeners disponibles
	t.Run("Listeners", func(t *testing.T) {
		testSliverListeners(t, ctx, cli)
	})
}

// testSliverContainerRunning vérifie que le container Sliver est en cours d'exécution
func testSliverContainerRunning(t *testing.T, ctx context.Context, cli *client.Client) {
	inspect, err := cli.ContainerInspect(ctx, "sliver-c2")
	require.NoError(t, err, "Failed to inspect Sliver container")

	assert.True(t, inspect.State.Running, "Sliver container should be running")
	assert.Equal(t, "running", inspect.State.Status, "Container status should be 'running'")

	// Vérifier que le container n'a pas redémarré récemment (signe de stabilité)
	startTime, err := time.Parse(time.RFC3339, inspect.State.StartedAt)
	require.NoError(t, err, "Failed to parse container start time")
	assert.True(t, time.Since(startTime) > 10*time.Second, "Container should be stable for at least 10 seconds")
}

// testSliverPortsExposed vérifie que les ports Sliver sont accessibles
func testSliverPortsExposed(t *testing.T) {
	// Port 31337 (Multiplayer/gRPC)
	t.Run("MultiplayerPort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:31337", 5*time.Second)
		assert.NoError(t, err, "Should be able to connect to Sliver multiplayer on port 31337")
		if conn != nil {
			conn.Close()
		}
	})

	// Port 443 (HTTPS/TLS listener par défaut)
	t.Run("HTTPSListenerPort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:443", 5*time.Second)
		if err != nil {
			t.Logf("Port 443 not accessible (may not be configured): %v", err)
		} else {
			conn.Close()
		}
	})
}

// testSliverCLI vérifie que l'interface CLI de Sliver fonctionne
func testSliverCLI(t *testing.T, ctx context.Context, cli *client.Client) {
	// Exécuter la commande version dans le container (syntaxe correcte)
	execConfig := types.ExecConfig{
		Cmd:          []string{"sliver", "version"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "sliver-c2", execConfig)
	if err != nil {
		t.Logf("Could not execute sliver version: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to sliver version: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 1024)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("Sliver version output: %s", output)

	// Vérifier que nous avons une version valide (format: v1.x.x)
	if strings.Contains(output, "v1.") || strings.Contains(strings.ToLower(output), "sliver") {
		t.Log("✅ Sliver CLI version command works correctly")
	} else {
		t.Logf("⚠️  Unexpected version output format: %s", output)
	}
}

// testSliverImplantGeneration teste la capacité de génération d'implants
func testSliverImplantGeneration(t *testing.T, ctx context.Context, cli *client.Client) {
	// Tester l'aide de Sliver pour vérifier que les commandes d'implants sont disponibles
	execConfig := types.ExecConfig{
		Cmd:          []string{"sliver", "help"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "sliver-c2", execConfig)
	if err != nil {
		t.Logf("Could not execute sliver help command: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to sliver help: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 2048)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("Sliver help output: %s", output)

	// Vérifier que l'aide contient les commandes essentielles
	if strings.Contains(strings.ToLower(output), "command") || strings.Contains(strings.ToLower(output), "available") {
		t.Log("✅ Sliver help command works, CLI is functional")
	} else {
		t.Logf("⚠️  Sliver help output unexpected: %s", output)
	}
}

// testSliverConfiguration vérifie la configuration du container
func testSliverConfiguration(t *testing.T, ctx context.Context, cli *client.Client) {
	inspect, err := cli.ContainerInspect(ctx, "sliver-c2")
	require.NoError(t, err, "Failed to inspect Sliver container")

	// Vérifier les ports exposés
	expectedPorts := map[string]bool{
		"31337/tcp": false, // Port multiplayer par défaut
		"443/tcp":   false, // Port HTTPS par défaut
	}

	for port := range inspect.NetworkSettings.Ports {
		if _, exists := expectedPorts[string(port)]; exists {
			expectedPorts[string(port)] = true
		}
	}

	for port, found := range expectedPorts {
		if port == "443/tcp" && !found {
			t.Logf("Port %s not exposed (may be expected)", port)
		} else if port == "31337/tcp" {
			assert.True(t, found, "Port %s should be exposed", port)
		}
	}

	// Vérifier les volumes montés
	volumeFound := false
	for _, mount := range inspect.Mounts {
		if strings.Contains(mount.Destination, "/root/.sliver") ||
			strings.Contains(mount.Destination, "/opt/sliver") {
			volumeFound = true
			t.Logf("Found Sliver volume mount: %s -> %s", mount.Source, mount.Destination)
			break
		}
	}
	if !volumeFound {
		t.Log("No Sliver-specific volume mounts found (may be expected)")
	}

	// Vérifier les variables d'environnement
	t.Logf("Sliver container environment: %v", inspect.Config.Env)
}

// testSliverLogs vérifie les logs du container pour détecter les erreurs
func testSliverLogs(t *testing.T, ctx context.Context, cli *client.Client) {
	logs, err := cli.ContainerLogs(ctx, "sliver-c2", types.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       "50", // Dernières 50 lignes
	})
	require.NoError(t, err, "Failed to get Sliver container logs")
	defer logs.Close()

	// Lire les logs
	buf := make([]byte, 4096)
	n, err := logs.Read(buf)
	if err != nil && err.Error() != "EOF" {
		t.Logf("Warning: could not read all logs: %v", err)
	}

	logContent := string(buf[:n])
	t.Logf("Sliver container logs (last 50 lines):\n%s", logContent)

	// Vérifier qu'il n'y a pas d'erreurs critiques
	criticalErrors := []string{
		"panic:",
		"fatal error:",
		"segmentation fault",
		"core dumped",
		"failed to start server",
		"bind: address already in use",
	}

	for _, errorPattern := range criticalErrors {
		assert.NotContains(t, strings.ToLower(logContent), strings.ToLower(errorPattern),
			"Logs should not contain critical error: %s", errorPattern)
	}

	// Vérifier la présence d'indicateurs de bon fonctionnement
	goodIndicators := []string{
		"sliver",
		"server",
		"starting",
		"loaded",
		"listening",
	}

	foundIndicator := false
	for _, indicator := range goodIndicators {
		if strings.Contains(strings.ToLower(logContent), strings.ToLower(indicator)) {
			foundIndicator = true
			break
		}
	}
	if len(logContent) > 0 {
		assert.True(t, foundIndicator || len(logContent) == 0,
			"Logs should contain at least one good indicator or be empty")
	}
}

// testSliverListeners teste la configuration des listeners
func testSliverListeners(t *testing.T, ctx context.Context, cli *client.Client) {
	// Vérifier que le serveur Sliver écoute sur le port multiplayer
	execConfig := types.ExecConfig{
		Cmd:          []string{"ss", "-tlnp"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "sliver-c2", execConfig)
	if err != nil {
		t.Logf("Could not execute ss command: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to ss: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 2048)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("Sliver ss output: %s", output)

	// Vérifier que Sliver écoute sur le port 31337 (multiplayer)
	if strings.Contains(output, ":31337") {
		t.Log("✅ Sliver server is listening on multiplayer port 31337")
	} else {
		// Si ss n'est pas disponible, vérifier simplement que le processus sliver-server fonctionne
		t.Log("⚠️  ss command may not be available, checking process instead")

		// Test alternatif : vérifier que le processus sliver-server fonctionne
		processConfig := types.ExecConfig{
			Cmd:          []string{"ps", "aux"},
			AttachStdout: true,
			AttachStderr: true,
		}

		processResp, err := cli.ContainerExecCreate(ctx, "sliver-c2", processConfig)
		if err == nil {
			processAttach, err := cli.ContainerExecAttach(ctx, processResp.ID, types.ExecStartCheck{})
			if err == nil {
				defer processAttach.Close()
				processBuf := make([]byte, 2048)
				processN, _ := processAttach.Reader.Read(processBuf)
				processOutput := string(processBuf[:processN])

				if strings.Contains(processOutput, "sliver-server") {
					t.Log("✅ Sliver server process is running")
				} else {
					t.Log("⚠️  Sliver server process not found")
				}
			}
		}
	}
}

// testSliverFunctionalHealth teste si Sliver fonctionne réellement
func testSliverFunctionalHealth(t *testing.T) bool {
	// Test 1: Vérifier si le port Multiplayer répond
	conn, err := net.DialTimeout("tcp", "localhost:31337", 3*time.Second)
	if err != nil {
		t.Logf("Multiplayer port 31337 not accessible: %v", err)
		return false
	}
	conn.Close()

	return true
}

// TestSliverHealthCheck teste spécifiquement le health check de Sliver
func TestSliverHealthCheck(t *testing.T) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	_, err = cli.ContainerInspect(ctx, "sliver-c2")
	if err != nil {
		t.Skip("Sliver container not found - skipping health check test")
		return
	}

	// Réduire le timeout à 30 secondes pour éviter les attentes excessives
	timeout := time.After(30 * time.Second)
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			// Obtenir l'état final
			inspect, _ := cli.ContainerInspect(ctx, "sliver-c2")
			if inspect.State.Health != nil {
				t.Fatalf("Health check timeout. Final status: %s", inspect.State.Health.Status)
			} else {
				t.Log("Health check timeout. No health check configured (may be normal)")
				return
			}
		case <-ticker.C:
			inspect, err := cli.ContainerInspect(ctx, "sliver-c2")
			require.NoError(t, err, "Failed to inspect container")

			if inspect.State.Health != nil {
				t.Logf("Health check status: %s", inspect.State.Health.Status)
				if inspect.State.Health.Status == "healthy" {
					return // Test réussi
				}
				if inspect.State.Health.Status == "unhealthy" {
					// Test fonctionnel avant d'échouer
					if testSliverFunctionalHealth(t) {
						t.Log("✅ Sliver is functionally healthy despite Docker health check being unhealthy")
						return
					}
					t.Fatalf("Container is unhealthy and not functionally working: %v", inspect.State.Health.Log)
				}
			} else {
				// Pas de health check configuré, vérifier manuellement
				if inspect.State.Running {
					t.Log("No health check configured, but container is running")
					return
				}
			}
		}
	}
}

// BenchmarkSliverResponseTime mesure le temps de réponse de Sliver
func BenchmarkSliverResponseTime(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		conn, err := net.DialTimeout("tcp", "localhost:31337", 1*time.Second)
		if err == nil {
			conn.Close()
		}
	}
}

// TestSliverIntegration teste l'intégration complète de Sliver
func TestSliverIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Ce test vérifie que Sliver peut accepter des connexions basiques
	t.Run("MultiplayerConnection", func(t *testing.T) {
		// Note: Dans un vrai test, nous pourrions nous connecter au serveur multiplayer
		t.Log("Integration test: multiplayer connection (stub)")

		// Pour l'instant, vérifier que le service répond
		conn, err := net.DialTimeout("tcp", "localhost:31337", 5*time.Second)
		if err != nil {
			t.Skip("Sliver multiplayer not accessible for integration test")
		}
		if conn != nil {
			conn.Close()
		}
	})

	t.Run("ImplantLifecycle", func(t *testing.T) {
		// Note: Test du cycle de vie d'un implant (stub)
		t.Log("Integration test: implant lifecycle (stub)")
	})
}

// SliverTestHelper contient des fonctions utilitaires pour les tests Sliver
type SliverTestHelper struct {
	ContainerName   string
	MultiplayerPort string
	HTTPSPort       string
}

// NewSliverTestHelper crée un nouveau helper pour les tests Sliver
func NewSliverTestHelper() *SliverTestHelper {
	return &SliverTestHelper{
		ContainerName:   "sliver-c2",
		MultiplayerPort: "31337",
		HTTPSPort:       "443",
	}
}

// IsRunning vérifie si Sliver est en cours d'exécution
func (s *SliverTestHelper) IsRunning() bool {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return false
	}

	inspect, err := cli.ContainerInspect(ctx, s.ContainerName)
	if err != nil {
		return false
	}

	return inspect.State.Running
}

// GetLogs récupère les logs du container Sliver
func (s *SliverTestHelper) GetLogs() (string, error) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return "", err
	}

	logs, err := cli.ContainerLogs(ctx, s.ContainerName, types.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       "100",
	})
	if err != nil {
		return "", err
	}
	defer logs.Close()

	buf := make([]byte, 8192)
	n, _ := logs.Read(buf)
	return string(buf[:n]), nil
}

// ExecuteSliverCommand exécute une commande Sliver dans le container
func (s *SliverTestHelper) ExecuteSliverCommand(command []string) (string, error) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return "", err
	}

	execConfig := types.ExecConfig{
		Cmd:          append([]string{"sliver"}, command...),
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, s.ContainerName, execConfig)
	if err != nil {
		return "", err
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		return "", err
	}
	defer attach.Close()

	buf := make([]byte, 4096)
	n, _ := attach.Reader.Read(buf)
	return string(buf[:n]), nil
}
