package test

import (
	"context"
	"net"
	"testing"
	"time"

	"github.com/docker/docker/client"
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
			// Attendre jusqu'à 5 min que le conteneur soit RUNNING & healthy
			deadline := time.Now().Add(5 * time.Minute)
			for {
				// Inspecter le conteneur
				inspect, err := cli.ContainerInspect(ctx, name)
				if err == nil && inspect.State != nil && inspect.State.Running {
					// Si un healthcheck est défini, vérifier qu'il est healthy
					if inspect.State.Health == nil || inspect.State.Health.Status == "healthy" {
						// Tester le port TCP
						address := net.JoinHostPort("127.0.0.1", port)
						conn, errDial := net.DialTimeout("tcp", address, 2*time.Second)
						if errDial == nil {
							_ = conn.Close()
							break // OK
						}
					}
				}

				if time.Now().After(deadline) {
					t.Fatalf("%s n'est pas prêt après 5 min", name)
				}
				time.Sleep(5 * time.Second)
			}
		})
	}
}
