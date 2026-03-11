#!/bin/bash

echo "=== KIOSK SIMPLES PARA TESTE ==="
echo ""

# Ambiente
export DISPLAY=:0
export XAUTHORITY=/home/informa/.Xauthority

# Obter primeira URL ativa do tabs.json
URL=$(python3 << 'PYTHON'
import json
try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    tabs = data if isinstance(data, list) else data.get("tabs", [])
    
    for tab in tabs:
        if tab.get("enabled", True):
            url = tab.get("url", "").strip()
            if url:
                print(url)
                break
    else:
        print("https://google.com")
        
except:
    print("https://google.com")
PYTHON
)

echo "URL encontrada: $URL"

# Fechar Firefox anteriores
echo "Fechando Firefox anteriores..."
pkill -f firefox 2>/dev/null || true
sleep 3

# Abrir Firefox em modo kiosk
echo "Abrindo Firefox em modo kiosk..."
firefox --kiosk "$URL" &

# Aguardar
sleep 5

# Verificar
if pgrep -f firefox > /dev/null; then
    echo "✓ Firefox iniciado com sucesso!"
    echo "URL: $URL"
    echo "Pressione Ctrl+C para parar"
    
    # Manter rodando
    while pgrep -f firefox > /dev/null; do
        sleep 1
    done
    
    echo "Firefox finalizado"
else
    echo "✗ Firefox NÃO iniciou"
    echo "Verificando problemas..."
    echo "Firefox: $(which firefox)"
    echo "DISPLAY: $DISPLAY"
    echo "Usuario: $(whoami)"
    exit 1
fi
