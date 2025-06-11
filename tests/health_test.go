package test

import (
	"context"
	"net"
	"testing"
	"time"

	"github.com/docker/docker/client"
	"github.com/stretchr/testify/assert"
)

// TestC2ContainersHealth vérifie que chaque conteneur C2 est en cours d'exécution,
// que son Healthcheck (si présent) est à healthy et que les ports exposés
// répondent sur localhost.
func TestC2ContainersHealth(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		t.Fatalf("⚠️  Impossible d'initialiser le client Docker : %v", err)
	}

	// Nom du conteneur → port externe principal à tester.
	containers := map[string]string{
		"havoc-c2":      "40056",
		"sliver-c2":     "31337",
		"empire-c2":     "5000",
		"metasploit-c2": "8080",
		"mythic-react":  "7443",
	}

	for name, port := range containers {
		name := name // capture range variable
		port := port
		t.Run(name, func(t *testing.T) {
			// Inspecter le conteneur
			inspect, err := cli.ContainerInspect(ctx, name)
			assert.NoError(t, err, "Le conteneur %s devrait exister", name)

			// Vérifier qu'il est RUNNING
			assert.True(t, inspect.State.Running, "Le conteneur %s doit être en cours d'exécution", name)

			// Vérifier le statut de healthcheck si défini
			if inspect.State.Health != nil {
				assert.Equal(t, "healthy", inspect.State.Health.Status, "Healthcheck de %s", name)
			}

			// Tester l'accessibilité réseau du port exposé
			address := net.JoinHostPort("127.0.0.1", port)
			conn, err := net.DialTimeout("tcp", address, 2*time.Second)
			assert.NoError(t, err, "Impossible de se connecter à %s:%s", name, port)
			if err == nil {
				_ = conn.Close()
			}
		})
	}
}
