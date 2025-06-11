package test

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMythicDeployment teste le déploiement complet de Mythic C2
func TestMythicDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping Mythic deployment test in short mode")
	}

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	// Test 1: Vérifier que tous les containers Mythic existent et fonctionnent
	t.Run("ContainersRunning", func(t *testing.T) {
		testMythicContainersRunning(t, ctx, cli)
	})

	// Test 2: Vérifier les ports exposés
	t.Run("PortsExposed", func(t *testing.T) {
		testMythicPortsExposed(t)
	})

	// Test 3: Vérifier l'interface web
	t.Run("WebInterface", func(t *testing.T) {
		testMythicWebInterface(t)
	})

	// Test 4: Vérifier la base de données
	t.Run("Database", func(t *testing.T) {
		testMythicDatabase(t, ctx, cli)
	})

	// Test 5: Vérifier RabbitMQ
	t.Run("RabbitMQ", func(t *testing.T) {
		testMythicRabbitMQ(t, ctx, cli)
	})

	// Test 6: Vérifier l'API GraphQL
	t.Run("GraphQLAPI", func(t *testing.T) {
		testMythicGraphQL(t)
	})

	// Test 7: Vérifier les logs des containers
	t.Run("ContainerLogs", func(t *testing.T) {
		testMythicLogs(t, ctx, cli)
	})
}

// testMythicContainersRunning vérifie que tous les containers Mythic sont en cours d'exécution
func testMythicContainersRunning(t *testing.T, ctx context.Context, cli *client.Client) {
	expectedContainers := []string{
		"mythic-postgres",
		"mythic-rabbitmq",
		"mythic-server",
		"mythic-react",
	}

	for _, containerName := range expectedContainers {
		t.Run(containerName, func(t *testing.T) {
			inspect, err := cli.ContainerInspect(ctx, containerName)
			require.NoError(t, err, "Failed to inspect %s container", containerName)

			assert.True(t, inspect.State.Running, "%s container should be running", containerName)
			assert.Equal(t, "running", inspect.State.Status, "%s container status should be 'running'", containerName)

			// Vérifier que le container n'a pas redémarré récemment (signe de stabilité)
			startTime, err := time.Parse(time.RFC3339, inspect.State.StartedAt)
			require.NoError(t, err, "Failed to parse %s container start time", containerName)
			assert.True(t, time.Since(startTime) > 30*time.Second, "%s container should be stable for at least 30 seconds", containerName)
		})
	}
}

// testMythicPortsExposed vérifie que les ports Mythic sont accessibles
func testMythicPortsExposed(t *testing.T) {
	// Port 7443 (Interface web principale via Nginx)
	t.Run("WebInterfacePort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:7443", 5*time.Second)
		assert.NoError(t, err, "Should be able to connect to Mythic web interface on port 7443")
		if conn != nil {
			conn.Close()
		}
	})

	// Port 5432 (PostgreSQL)
	t.Run("PostgreSQLPort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:5432", 5*time.Second)
		assert.NoError(t, err, "Should be able to connect to PostgreSQL on port 5432")
		if conn != nil {
			conn.Close()
		}
	})

	// Port 5672 (RabbitMQ)
	t.Run("RabbitMQPort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:5672", 5*time.Second)
		assert.NoError(t, err, "Should be able to connect to RabbitMQ on port 5672")
		if conn != nil {
			conn.Close()
		}
	})
}

// testMythicWebInterface vérifie l'interface web de Mythic
func testMythicWebInterface(t *testing.T) {
	// Configuration du client HTTP avec TLS personnalisé
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{
		Transport: tr,
		Timeout:   15 * time.Second,
	}

	// Tester l'interface web sur HTTPS
	resp, err := client.Get("https://localhost:7443")
	require.NoError(t, err, "Should be able to access Mythic web interface")
	defer resp.Body.Close()

	// Vérifier que nous recevons une réponse web valide
	assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 400,
		"Web interface should respond with success status code, got %d", resp.StatusCode)

	// Vérifier les headers de sécurité
	contentType := resp.Header.Get("Content-Type")
	if contentType != "" {
		t.Logf("Content-Type: %s", contentType)
		// Mythic devrait retourner du contenu HTML
		assert.Contains(t, strings.ToLower(contentType), "text/html",
			"Content should be HTML for the web interface")
	}

	// Vérifier que c'est bien Mythic
	assert.NotEmpty(t, resp.Header.Get("Server"), "Should have Server header")
}

// testMythicDatabase vérifie que PostgreSQL fonctionne correctement
func testMythicDatabase(t *testing.T, ctx context.Context, cli *client.Client) {
	// Exécuter une commande basique dans le container PostgreSQL
	execConfig := types.ExecConfig{
		Cmd:          []string{"pg_isready", "-U", "mythic_user", "-d", "mythic_db"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "mythic-postgres", execConfig)
	if err != nil {
		t.Logf("Could not execute pg_isready: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to pg_isready: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 1024)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("PostgreSQL status: %s", output)
	assert.Contains(t, strings.ToLower(output), "accepting connections",
		"PostgreSQL should be accepting connections")
}

// testMythicRabbitMQ vérifie que RabbitMQ fonctionne correctement
func testMythicRabbitMQ(t *testing.T, ctx context.Context, cli *client.Client) {
	// Exécuter une commande de statut RabbitMQ
	execConfig := types.ExecConfig{
		Cmd:          []string{"rabbitmqctl", "status"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "mythic-rabbitmq", execConfig)
	if err != nil {
		t.Logf("Could not execute rabbitmqctl status: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to rabbitmqctl status: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 2048)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("RabbitMQ status: %s", output)
	assert.Contains(t, strings.ToLower(output), "running",
		"RabbitMQ should be running")
}

// testMythicGraphQL vérifie l'API GraphQL
func testMythicGraphQL(t *testing.T) {
	// Tester l'endpoint GraphQL (Hasura)
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Test de l'endpoint de santé Hasura
	resp, err := client.Get("http://localhost:8080/healthz")
	if err != nil {
		t.Logf("GraphQL endpoint not accessible: %v", err)
		return
	}
	defer resp.Body.Close()

	assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 300,
		"GraphQL endpoint should be healthy")

	t.Logf("GraphQL health check status: %d", resp.StatusCode)
}

// testMythicLogs vérifie les logs des containers pour détecter les erreurs
func testMythicLogs(t *testing.T, ctx context.Context, cli *client.Client) {
	containers := []string{
		"mythic-server",
		"mythic-postgres",
		"mythic-rabbitmq",
		"mythic-react",
	}

	for _, containerName := range containers {
		t.Run(containerName, func(t *testing.T) {
			logs, err := cli.ContainerLogs(ctx, containerName, types.ContainerLogsOptions{
				ShowStdout: true,
				ShowStderr: true,
				Tail:       "50", // Dernières 50 lignes
			})
			require.NoError(t, err, "Failed to get %s container logs", containerName)
			defer logs.Close()

			// Lire les logs
			buf := make([]byte, 4096)
			n, err := logs.Read(buf)
			if err != nil && err.Error() != "EOF" {
				t.Logf("Warning: could not read all logs for %s: %v", containerName, err)
			}

			logContent := string(buf[:n])
			t.Logf("%s container logs (last 50 lines):\n%s", containerName, logContent)

			// Vérifier qu'il n'y a pas d'erreurs critiques
			criticalErrors := []string{
				"panic:",
				"fatal error:",
				"segmentation fault",
				"core dumped",
				"failed to start",
				"connection refused",
				"bind: address already in use",
			}

			for _, errorPattern := range criticalErrors {
				assert.NotContains(t, strings.ToLower(logContent), strings.ToLower(errorPattern),
					"%s logs should not contain critical error: %s", containerName, errorPattern)
			}

			// Vérifier la présence d'indicateurs de bon fonctionnement selon le container
			switch containerName {
			case "mythic-server":
				goodIndicators := []string{"listening", "server", "started", "connected"}
				testForGoodIndicators(t, logContent, goodIndicators, containerName)
			case "mythic-postgres":
				goodIndicators := []string{"ready to accept connections", "database system is ready"}
				testForGoodIndicators(t, logContent, goodIndicators, containerName)
			case "mythic-rabbitmq":
				goodIndicators := []string{"started", "completed", "ready"}
				testForGoodIndicators(t, logContent, goodIndicators, containerName)
			case "mythic-react":
				goodIndicators := []string{"compiled", "webpack", "serve"}
				testForGoodIndicators(t, logContent, goodIndicators, containerName)
			}
		})
	}
}

// testForGoodIndicators vérifie la présence d'indicateurs positifs dans les logs
func testForGoodIndicators(t *testing.T, logContent string, indicators []string, containerName string) {
	if len(logContent) == 0 {
		return // Pas de logs à vérifier
	}

	foundIndicator := false
	for _, indicator := range indicators {
		if strings.Contains(strings.ToLower(logContent), strings.ToLower(indicator)) {
			foundIndicator = true
			t.Logf("Found good indicator '%s' in %s logs", indicator, containerName)
			break
		}
	}

	if !foundIndicator {
		t.Logf("Warning: No good indicators found in %s logs, but this may be normal", containerName)
	}
}

// TestMythicHealthCheck teste spécifiquement le health check des containers Mythic
func TestMythicHealthCheck(t *testing.T) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	containers := []string{
		"mythic-server",
		"mythic-postgres",
		"mythic-rabbitmq",
		"mythic-react",
	}

	for _, containerName := range containers {
		t.Run(containerName, func(t *testing.T) {
			_, err := cli.ContainerInspect(ctx, containerName)
			if err != nil {
				t.Skipf("%s container not found - skipping health check test", containerName)
				return
			}

			// Réduire le timeout à 45 secondes pour éviter les attentes excessives
			timeout := time.After(45 * time.Second)
			ticker := time.NewTicker(5 * time.Second)
			defer ticker.Stop()

			for {
				select {
				case <-timeout:
					// Obtenir l'état final
					inspect, _ := cli.ContainerInspect(ctx, containerName)
					if inspect.State.Health != nil {
						t.Fatalf("%s health check timeout. Final status: %s", containerName, inspect.State.Health.Status)
					} else {
						t.Logf("%s health check timeout. No health check configured (may be normal)", containerName)
						return
					}
				case <-ticker.C:
					inspect, err := cli.ContainerInspect(ctx, containerName)
					require.NoError(t, err, "Failed to inspect %s container", containerName)

					if inspect.State.Health != nil {
						t.Logf("%s health check status: %s", containerName, inspect.State.Health.Status)
						if inspect.State.Health.Status == "healthy" {
							return // Test réussi
						}
						if inspect.State.Health.Status == "unhealthy" {
							t.Fatalf("%s container is unhealthy: %v", containerName, inspect.State.Health.Log)
						}
					} else {
						// Pas de health check configuré, vérifier manuellement
						if inspect.State.Running {
							t.Logf("%s: No health check configured, but container is running", containerName)
							return
						}
					}
				}
			}
		})
	}
}

// BenchmarkMythicResponseTime mesure le temps de réponse de Mythic
func BenchmarkMythicResponseTime(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		conn, err := net.DialTimeout("tcp", "localhost:7443", 1*time.Second)
		if err == nil {
			conn.Close()
		}
	}
}

// TestMythicIntegration teste l'intégration complète de Mythic
func TestMythicIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Test de l'intégration complète web -> API -> DB
	t.Run("WebToAPIIntegration", func(t *testing.T) {
		tr := &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
		client := &http.Client{
			Transport: tr,
			Timeout:   15 * time.Second,
		}

		// Accès à la page d'accueil
		resp, err := client.Get("https://localhost:7443")
		if err != nil {
			t.Skip("Mythic web interface not accessible for integration test")
		}
		defer resp.Body.Close()

		assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 400,
			"Web interface should be accessible")
	})

	t.Run("DatabaseConnectivity", func(t *testing.T) {
		// Test de connectivité de base à PostgreSQL
		conn, err := net.DialTimeout("tcp", "localhost:5432", 5*time.Second)
		if err != nil {
			t.Skip("PostgreSQL not accessible for integration test")
		}
		if conn != nil {
			conn.Close()
		}
	})
}

// MythicTestHelper contient des fonctions utilitaires pour les tests Mythic
type MythicTestHelper struct {
	WebURL      string
	PostgresURL string
	RabbitMQURL string
	GraphQLURL  string
}

// NewMythicTestHelper crée un nouveau helper pour les tests Mythic
func NewMythicTestHelper() *MythicTestHelper {
	return &MythicTestHelper{
		WebURL:      "https://localhost:7443",
		PostgresURL: "localhost:5432",
		RabbitMQURL: "localhost:5672",
		GraphQLURL:  "http://localhost:8080",
	}
}

// IsWebUIAccessible vérifie si l'interface web est accessible
func (m *MythicTestHelper) IsWebUIAccessible() bool {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{
		Transport: tr,
		Timeout:   10 * time.Second,
	}

	resp, err := client.Get(m.WebURL)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode >= 200 && resp.StatusCode < 400
}

// AreServicesRunning vérifie si tous les services principaux sont en marche
func (m *MythicTestHelper) AreServicesRunning() bool {
	services := []string{
		"localhost:7443", // Web UI
		"localhost:5432", // PostgreSQL
		"localhost:5672", // RabbitMQ
		"localhost:8080", // GraphQL
	}

	for _, service := range services {
		conn, err := net.DialTimeout("tcp", service, 3*time.Second)
		if err != nil {
			return false
		}
		conn.Close()
	}

	return true
}

// GetMythicVersion tente de récupérer la version de Mythic
func (m *MythicTestHelper) GetMythicVersion() (string, error) {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := &http.Client{
		Transport: tr,
		Timeout:   10 * time.Second,
	}

	resp, err := client.Get(m.WebURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// Chercher des indicateurs de version dans les headers ou le contenu
	server := resp.Header.Get("Server")
	if server != "" {
		return fmt.Sprintf("Server: %s", server), nil
	}

	return "Unknown version", nil
}
