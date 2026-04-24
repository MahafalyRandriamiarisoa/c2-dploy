#!/bin/bash
set -euo pipefail

: "${HAVOC_ADMIN_PASSWORD:?HAVOC_ADMIN_PASSWORD env var required (défini par Terraform)}"

echo "🗡️  Démarrage de Havoc C2..."

# Créer la configuration par défaut si elle n'existe pas
if [ ! -f /opt/havoc/data/havoc.yaotl ]; then
    cat > /opt/havoc/data/havoc.yaotl << EOF
Teamserver {
    Host = "0.0.0.0"
    Port = 40056

    Build {
        Compiler64 = "/usr/bin/x86_64-w64-mingw32-gcc"
        Compiler86 = "/usr/bin/i686-w64-mingw32-gcc"
        Nasm = "/usr/bin/nasm"
    }
}

Operators {
    user "admin" {
        Password = "${HAVOC_ADMIN_PASSWORD}"
    }
}

Listeners {
    Http {
        Name         = "Default HTTP"
        HostBind     = "0.0.0.0"
        PortBind     = 443
        Hosts        = ["172.20.0.10"]
        HostRotation = "round-robin"
        Secure       = true
        UserAgent    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
}

Demon {
    Sleep = 2
    Jitter = 30
}
EOF
fi

cd /opt/havoc

# Démarrer le teamserver Havoc
echo "Démarrage du Havoc Teamserver..."
./havoc server --profile /opt/havoc/data/havoc.yaotl

# Garder le container en vie
tail -f /dev/null 