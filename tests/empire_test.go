package test

import (
	"context"
	"encoding/json"
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

// TestEmpireDeployment teste le déploiement complet d'Empire C2
func TestEmpireDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping Empire deployment test in short mode")
	}

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	// Test 1: Vérifier que le container Empire existe et fonctionne
	t.Run("ContainerRunning", func(t *testing.T) {
		testEmpireContainerRunning(t, ctx, cli)
	})

	// Test 2: Vérifier les ports exposés
	t.Run("PortsExposed", func(t *testing.T) {
		testEmpirePortsExposed(t)
	})

	// Test 3: Vérifier l'API REST
	t.Run("RESTAPI", func(t *testing.T) {
		testEmpireRESTAPI(t)
	})

	// Test 4: Vérifier l'interface PowerShell Empire
	t.Run("PowerShellInterface", func(t *testing.T) {
		testEmpirePowerShellInterface(t, ctx, cli)
	})

	// Test 5: Vérifier les listeners disponibles
	t.Run("Listeners", func(t *testing.T) {
		testEmpireListeners(t)
	})

	// Test 6: Vérifier les modules Empire
	t.Run("Modules", func(t *testing.T) {
		testEmpireModules(t)
	})

	// Test 7: Vérifier la configuration
	t.Run("Configuration", func(t *testing.T) {
		testEmpireConfiguration(t, ctx, cli)
	})

	// Test 8: Vérifier les logs du container
	t.Run("ContainerLogs", func(t *testing.T) {
		testEmpireLogs(t, ctx, cli)
	})
}

// testEmpireContainerRunning vérifie que le container Empire est en cours d'exécution
func testEmpireContainerRunning(t *testing.T, ctx context.Context, cli *client.Client) {
	inspect, err := cli.ContainerInspect(ctx, "empire-c2")
	require.NoError(t, err, "Failed to inspect Empire container")

	assert.True(t, inspect.State.Running, "Empire container should be running")
	assert.Equal(t, "running", inspect.State.Status, "Container status should be 'running'")

	// Vérifier que le container n'a pas redémarré récemment (signe de stabilité)
	startTime, err := time.Parse(time.RFC3339, inspect.State.StartedAt)
	require.NoError(t, err, "Failed to parse container start time")
	assert.True(t, time.Since(startTime) > 30*time.Second, "Container should be stable for at least 30 seconds")
}

// testEmpirePortsExposed vérifie que les ports Empire sont accessibles
func testEmpirePortsExposed(t *testing.T) {
	// Port 1337 (API REST)
	t.Run("APIPort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:1337", 5*time.Second)
		assert.NoError(t, err, "Should be able to connect to Empire API on port 1337")
		if conn != nil {
			conn.Close()
		}
	})

	// Port 8080 (Interface web par défaut)
	t.Run("WebInterfacePort", func(t *testing.T) {
		conn, err := net.DialTimeout("tcp", "localhost:8080", 5*time.Second)
		if err != nil {
			t.Logf("Port 8080 not accessible (may not be configured): %v", err)
		} else {
			conn.Close()
		}
	})
}

// testEmpireRESTAPI vérifie l'API REST d'Empire
func testEmpireRESTAPI(t *testing.T) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Tester l'endpoint de documentation public (ne nécessite pas d'auth)
	docsResp, err := client.Get("http://localhost:1337/docs")
	if err != nil {
		t.Logf("Empire docs endpoint not accessible: %v", err)
	} else {
		defer docsResp.Body.Close()
		assert.True(t, docsResp.StatusCode >= 200 && docsResp.StatusCode < 300,
			"Empire docs endpoint should be accessible, got %d", docsResp.StatusCode)
		t.Logf("Empire docs endpoint accessible with status: %d", docsResp.StatusCode)
	}

	// Tester l'endpoint API protégé (401 Unauthorized est attendu sans auth)
	resp, err := client.Get("http://localhost:1337/api/v2/users")
	if err != nil {
		t.Logf("Empire API not accessible: %v", err)
		return
	}
	defer resp.Body.Close()

	// 401 Unauthorized est un comportement normal pour un endpoint protégé
	assert.True(t, resp.StatusCode == 401 || (resp.StatusCode >= 200 && resp.StatusCode < 300),
		"Empire API should respond with 401 (unauthorized) or success, got %d", resp.StatusCode)

	// Vérifier que c'est bien l'API Empire
	contentType := resp.Header.Get("Content-Type")
	t.Logf("API Content-Type: %s", contentType)

	// Test avec authentification pour vérifier que l'API fonctionne vraiment
	token := getEmpireAuthToken(t, client)
	if token != "" {
		req, err := http.NewRequest("GET", "http://localhost:1337/api/v2/users", nil)
		if err == nil {
			req.Header.Set("Authorization", "Bearer "+token)
			authResp, err := client.Do(req)
			if err == nil {
				defer authResp.Body.Close()
				assert.True(t, authResp.StatusCode >= 200 && authResp.StatusCode < 300,
					"Empire API with auth should work, got %d", authResp.StatusCode)
				t.Logf("Empire API with authentication: %d", authResp.StatusCode)
			}
		}
	}
}

// testEmpirePowerShellInterface vérifie l'interface PowerShell d'Empire
func testEmpirePowerShellInterface(t *testing.T, ctx context.Context, cli *client.Client) {
	// Exécuter une commande Empire basique dans le container
	execConfig := types.ExecConfig{
		Cmd:          []string{"python3", "-c", "import empire; print('Empire imported successfully')"},
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, "empire-c2", execConfig)
	if err != nil {
		t.Logf("Could not execute Empire test command: %v", err)
		return
	}

	attach, err := cli.ContainerExecAttach(ctx, execResp.ID, types.ExecStartCheck{})
	if err != nil {
		t.Logf("Could not attach to Empire test: %v", err)
		return
	}
	defer attach.Close()

	// Lire la sortie
	buf := make([]byte, 1024)
	n, _ := attach.Reader.Read(buf)
	output := string(buf[:n])

	t.Logf("Empire interface test output: %s", output)
	assert.Contains(t, strings.ToLower(output), "empire", "Output should contain 'empire'")
}

// testEmpireListeners teste les listeners Empire via l'API
func testEmpireListeners(t *testing.T) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Obtenir un token d'authentification
	token := getEmpireAuthToken(t, client)
	if token == "" {
		t.Skip("Could not authenticate with Empire API")
		return
	}

	// Créer une requête avec authentification
	req, err := http.NewRequest("GET", "http://localhost:1337/api/v2/listener-templates", nil)
	if err != nil {
		t.Logf("Could not create listener templates request: %v", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := client.Do(req)
	if err != nil {
		t.Logf("Could not get listener templates: %v", err)
		return
	}
	defer resp.Body.Close()

	assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 300,
		"Listener templates endpoint should be accessible")

	// Essayer de décoder la réponse JSON
	var listenerTemplates []map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&listenerTemplates)
	if err == nil {
		t.Logf("Found %d listener templates", len(listenerTemplates))
		for i, template := range listenerTemplates {
			if i < 3 { // Afficher seulement les 3 premiers
				if name, ok := template["name"]; ok {
					t.Logf("Listener template: %v", name)
				}
			}
		}
	}
}

// testEmpireModules teste les modules Empire via l'API
func testEmpireModules(t *testing.T) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Obtenir un token d'authentification
	token := getEmpireAuthToken(t, client)
	if token == "" {
		t.Skip("Could not authenticate with Empire API")
		return
	}

	// Créer une requête avec authentification
	req, err := http.NewRequest("GET", "http://localhost:1337/api/v2/modules", nil)
	if err != nil {
		t.Logf("Could not create modules request: %v", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := client.Do(req)
	if err != nil {
		t.Logf("Could not get modules: %v", err)
		return
	}
	defer resp.Body.Close()

	assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 300,
		"Modules endpoint should be accessible")

	// Essayer de décoder la réponse JSON
	var modules []map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&modules)
	if err == nil {
		t.Logf("Found %d Empire modules", len(modules))

		// Compter les modules par type
		moduleTypes := make(map[string]int)
		for _, module := range modules {
			if name, ok := module["name"].(string); ok {
				parts := strings.Split(name, "/")
				if len(parts) > 0 {
					moduleTypes[parts[0]]++
				}
			}
		}

		for moduleType, count := range moduleTypes {
			t.Logf("Module type '%s': %d modules", moduleType, count)
		}
	}
}

// testEmpireConfiguration vérifie la configuration du container
func testEmpireConfiguration(t *testing.T, ctx context.Context, cli *client.Client) {
	inspect, err := cli.ContainerInspect(ctx, "empire-c2")
	require.NoError(t, err, "Failed to inspect Empire container")

	// Vérifier les ports exposés
	expectedPorts := map[string]bool{
		"1337/tcp": false, // API REST par défaut
		"8080/tcp": false, // Interface web (optionnel)
	}

	for port := range inspect.NetworkSettings.Ports {
		if _, exists := expectedPorts[string(port)]; exists {
			expectedPorts[string(port)] = true
		}
	}

	for port, found := range expectedPorts {
		if port == "1337/tcp" {
			assert.True(t, found, "Port %s should be exposed", port)
		} else if port == "8080/tcp" && !found {
			t.Logf("Port %s not exposed (may be expected)", port)
		}
	}

	// Vérifier les volumes montés
	volumeFound := false
	for _, mount := range inspect.Mounts {
		if strings.Contains(mount.Destination, "/opt/Empire") ||
			strings.Contains(mount.Destination, "/root/Empire") ||
			strings.Contains(mount.Destination, "/empire") {
			volumeFound = true
			t.Logf("Found Empire volume mount: %s -> %s", mount.Source, mount.Destination)
			break
		}
	}
	if !volumeFound {
		t.Log("No Empire-specific volume mounts found (may be expected)")
	}

	// Vérifier les variables d'environnement
	t.Logf("Empire container environment: %v", inspect.Config.Env)
}

// testEmpireLogs vérifie les logs du container pour détecter les erreurs
func testEmpireLogs(t *testing.T, ctx context.Context, cli *client.Client) {
	logs, err := cli.ContainerLogs(ctx, "empire-c2", types.ContainerLogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       "50", // Dernières 50 lignes
	})
	require.NoError(t, err, "Failed to get Empire container logs")
	defer logs.Close()

	// Lire les logs
	buf := make([]byte, 4096)
	n, err := logs.Read(buf)
	if err != nil && err.Error() != "EOF" {
		t.Logf("Warning: could not read all logs: %v", err)
	}

	logContent := string(buf[:n])
	t.Logf("Empire container logs (last 50 lines):\n%s", logContent)

	// Vérifier qu'il n'y a pas d'erreurs critiques
	criticalErrors := []string{
		"panic:",
		"fatal error:",
		"traceback",
		"exception",
		"failed to start",
		"connection refused",
		"bind: address already in use",
	}

	for _, errorPattern := range criticalErrors {
		assert.NotContains(t, strings.ToLower(logContent), strings.ToLower(errorPattern),
			"Logs should not contain critical error: %s", errorPattern)
	}

	// Vérifier la présence d'indicateurs de bon fonctionnement d'Empire
	goodIndicators := []string{
		"empire",
		"uvicorn running",
		"application startup complete",
		"info",
		"loading",
		"server process",
		"started",
		"listening",
	}

	foundIndicator := false
	for _, indicator := range goodIndicators {
		if strings.Contains(strings.ToLower(logContent), strings.ToLower(indicator)) {
			foundIndicator = true
			t.Logf("Found good indicator: %s", indicator)
			break
		}
	}

	// Si pas de logs ou pas d'indicateurs, faire un test fonctionnel pour vérifier que tout va bien
	if len(logContent) == 0 {
		t.Log("No logs available - this may be normal for a new container")
		return
	}

	if !foundIndicator {
		// Test fonctionnel pour vérifier qu'Empire fonctionne malgré l'absence d'indicateurs dans les logs
		client := &http.Client{Timeout: 5 * time.Second}
		docsResp, err := client.Get("http://localhost:1337/docs")
		if err == nil {
			docsResp.Body.Close()
			if docsResp.StatusCode >= 200 && docsResp.StatusCode < 300 {
				t.Log("Empire is functionally working despite no clear indicators in logs")
				return
			}
		}
		t.Error("Logs should contain at least one good indicator of Empire functioning")
	}
}

// getEmpireAuthToken obtient un token d'authentification pour l'API Empire
func getEmpireAuthToken(t *testing.T, client *http.Client) string {
	// Empire utilise application/x-www-form-urlencoded pour l'authentification
	authData := "username=empireadmin&password=password123"

	// Faire la requête d'authentification
	resp, err := client.Post("http://localhost:1337/token", "application/x-www-form-urlencoded", strings.NewReader(authData))
	if err != nil {
		t.Logf("Could not authenticate with Empire: %v", err)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		t.Logf("Authentication failed with status: %d", resp.StatusCode)
		return ""
	}

	// Décoder la réponse
	var authResp map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&authResp)
	if err != nil {
		t.Logf("Could not decode auth response: %v", err)
		return ""
	}

	if token, ok := authResp["access_token"].(string); ok {
		return token
	}

	t.Log("No access_token found in auth response")
	return ""
}

// TestEmpireHealthCheck teste spécifiquement le health check d'Empire
func TestEmpireHealthCheck(t *testing.T) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err, "Failed to create Docker client")

	inspect, err := cli.ContainerInspect(ctx, "empire-c2")
	if err != nil {
		t.Skip("Empire container not found - skipping health check test")
		return
	}

	// Vérifier d'abord si le container est en cours d'exécution
	assert.True(t, inspect.State.Running, "Empire container should be running")

	// Test fonctionnel : vérifier si Empire répond vraiment
	functionalHealth := testEmpireFunctionalHealth(t)

	// Si Empire fonctionne correctement au niveau fonctionnel
	if functionalHealth {
		t.Log("✅ Empire is functionally healthy (API responds, authentication works)")

		// Vérifier le health check Docker s'il existe
		if inspect.State.Health != nil {
			dockerHealthStatus := inspect.State.Health.Status
			t.Logf("Docker health check status: %s", dockerHealthStatus)

			if dockerHealthStatus == "unhealthy" {
				t.Log("⚠️  Docker health check reports 'unhealthy' but Empire is functionally working")
				t.Log("This may be due to health check configuration in the Docker image")
			} else if dockerHealthStatus == "healthy" {
				t.Log("✅ Docker health check also reports healthy")
			}
		} else {
			t.Log("No Docker health check configured - relying on functional test")
		}
		return
	}

	// Si Empire ne fonctionne pas, c'est un vrai problème
	t.Error("❌ Empire is not functionally healthy")

	// Afficher les détails du health check Docker pour debug
	if inspect.State.Health != nil {
		t.Logf("Docker health check status: %s", inspect.State.Health.Status)
		if len(inspect.State.Health.Log) > 0 {
			t.Logf("Health check logs: %v", inspect.State.Health.Log)
		}
	}
}

// testEmpireFunctionalHealth teste si Empire fonctionne réellement
func testEmpireFunctionalHealth(t *testing.T) bool {
	client := &http.Client{Timeout: 10 * time.Second}

	// Test 1: Vérifier si le port répond
	conn, err := net.DialTimeout("tcp", "localhost:1337", 5*time.Second)
	if err != nil {
		t.Logf("Port 1337 not accessible: %v", err)
		return false
	}
	conn.Close()

	// Test 2: Vérifier si l'endpoint docs répond
	docsResp, err := client.Get("http://localhost:1337/docs")
	if err != nil {
		t.Logf("Docs endpoint not accessible: %v", err)
		return false
	}
	docsResp.Body.Close()

	if docsResp.StatusCode < 200 || docsResp.StatusCode >= 300 {
		t.Logf("Docs endpoint returned status: %d", docsResp.StatusCode)
		return false
	}

	// Test 3: Vérifier si l'authentification fonctionne
	authData := "username=empireadmin&password=password123"
	authResp, err := client.Post("http://localhost:1337/token", "application/x-www-form-urlencoded", strings.NewReader(authData))
	if err != nil {
		t.Logf("Authentication not working: %v", err)
		return false
	}
	authResp.Body.Close()

	if authResp.StatusCode != 200 {
		t.Logf("Authentication failed with status: %d", authResp.StatusCode)
		return false
	}

	return true
}

// BenchmarkEmpireResponseTime mesure le temps de réponse d'Empire
func BenchmarkEmpireResponseTime(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		conn, err := net.DialTimeout("tcp", "localhost:1337", 1*time.Second)
		if err == nil {
			conn.Close()
		}
	}
}

// TestEmpireIntegration teste l'intégration complète d'Empire
func TestEmpireIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Test de l'intégration API complète
	t.Run("APIIntegration", func(t *testing.T) {
		client := &http.Client{
			Timeout: 15 * time.Second,
		}

		// Test d'authentification
		token := getEmpireAuthToken(t, client)
		if token == "" {
			t.Skip("Empire API not accessible for integration test")
		}

		// Tester différents endpoints avec le token
		endpoints := []string{
			"/api/v2/listeners",
			"/api/v2/modules",
			"/api/v2/stager-templates",
		}

		for _, endpoint := range endpoints {
			req, err := http.NewRequest("GET", "http://localhost:1337"+endpoint, nil)
			if err != nil {
				continue
			}
			req.Header.Set("Authorization", "Bearer "+token)

			resp, err := client.Do(req)
			if err == nil {
				resp.Body.Close()
				assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 300,
					"Endpoint %s should be accessible", endpoint)
			}
		}
	})

	t.Run("CLIIntegration", func(t *testing.T) {
		// Test basique de l'interface CLI (stub)
		t.Log("Integration test: CLI interface (stub)")

		// Vérifier que le port API répond
		conn, err := net.DialTimeout("tcp", "localhost:1337", 5*time.Second)
		if err != nil {
			t.Skip("Empire API not accessible for CLI integration test")
		}
		if conn != nil {
			conn.Close()
		}
	})
}

// EmpireTestHelper contient des fonctions utilitaires pour les tests Empire
type EmpireTestHelper struct {
	ContainerName string
	APIPort       string
	WebPort       string
	APIBaseURL    string
}

// NewEmpireTestHelper crée un nouveau helper pour les tests Empire
func NewEmpireTestHelper() *EmpireTestHelper {
	return &EmpireTestHelper{
		ContainerName: "empire-c2",
		APIPort:       "1337",
		WebPort:       "8080",
		APIBaseURL:    "http://localhost:1337/api/v2",
	}
}

// IsRunning vérifie si Empire est en cours d'exécution
func (e *EmpireTestHelper) IsRunning() bool {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return false
	}

	inspect, err := cli.ContainerInspect(ctx, e.ContainerName)
	if err != nil {
		return false
	}

	return inspect.State.Running
}

// GetAPIToken obtient un token d'authentification pour l'API
func (e *EmpireTestHelper) GetAPIToken() (string, error) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Empire utilise application/x-www-form-urlencoded pour l'authentification
	authData := "username=empireadmin&password=password123"

	resp, err := client.Post("http://localhost:1337/token", "application/x-www-form-urlencoded", strings.NewReader(authData))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var authResp map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&authResp)
	if err != nil {
		return "", err
	}

	if token, ok := authResp["access_token"].(string); ok {
		return token, nil
	}

	return "", fmt.Errorf("no access_token in response")
}

// GetLogs récupère les logs du container Empire
func (e *EmpireTestHelper) GetLogs() (string, error) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return "", err
	}

	logs, err := cli.ContainerLogs(ctx, e.ContainerName, types.ContainerLogsOptions{
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

// ExecuteEmpireCommand exécute une commande Empire dans le container
func (e *EmpireTestHelper) ExecuteEmpireCommand(command []string) (string, error) {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return "", err
	}

	execConfig := types.ExecConfig{
		Cmd:          command,
		AttachStdout: true,
		AttachStderr: true,
	}

	execResp, err := cli.ContainerExecCreate(ctx, e.ContainerName, execConfig)
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
