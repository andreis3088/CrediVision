#!/bin/bash

echo "Iniciando Kiosk Simples e Funcional..."

# Verificar se tem abas configuradas
CONFIG_FILE="/home/informa/Documents/kiosk-data/tabs.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERRO: Arquivo de configuracao nao encontrado"
    exit 1
fi

# Ler configuracao com Python
echo "Lendo configuracao..."
python3 << 'PYTHON_EOF'
import json
import sys

try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    tabs = data.get('tabs', [])
    
    if not tabs:
        print("ERRO: Nenhuma aba configurada")
        sys.exit(1)
    
    # Pegar primeira aba ativa
    for tab in tabs:
        if tab.get('enabled', True):
            url = tab.get('url', '').strip()
            name = tab.get('name', '').strip()
            tab_type = tab.get('type', 'url').strip().lower()
            
            if url:
                print(f"URL={url}")
                print(f"NAME={name}")
                print(f"TYPE={tab_type}")
                sys.exit(0)
    
    print("ERRO: Nenhuma aba ativa encontrada")
    sys.exit(1)
    
except Exception as e:
    print(f"ERRO: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
    echo "ERRO ao ler configuracao"
    exit 1
fi

# Carregar variaveis
eval "$(python3 << 'PYTHON_EOF'
import json
import sys

try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    tabs = data.get('tabs', [])
    
    for tab in tabs:
        if tab.get('enabled', True):
            url = tab.get('url', '').strip()
            name = tab.get('name', '').strip()
            tab_type = tab.get('type', 'url').strip().lower()
            
            if url:
                print(f"URL='{url}'")
                print(f"NAME='{name}'")
                print(f"TYPE='{tab_type}'")
                break
    
except Exception as e:
    print(f"ERRO: {e}")
    sys.exit(1)
PYTHON_EOF
)"

echo "Configuracao carregada:"
echo "  URL: $URL"
echo "  Nome: $NAME"
echo "  Tipo: $TYPE"

# Fechar Firefox anteriores
echo "Fechando Firefox anteriores..."
pkill -f firefox 2>/dev/null || true
sleep 3

# Verificar ambiente X11
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

if [ -z "$XAUTHORITY" ]; then
    export XAUTHORITY=/home/informa/.Xauthority
fi

echo "Ambiente:"
echo "  DISPLAY: $DISPLAY"
echo "  XAUTHORITY: $XAUTHORITY"

# Abrir Firefox em modo kiosk
echo "Abrindo Firefox em modo kiosk..."
echo "URL: $URL"

case "$TYPE" in
    "image")
        echo "Tipo: Imagem"
        firefox --kiosk "$URL" &
        ;;
    "video")
        echo "Tipo: Video"
        firefox --kiosk "$URL" &
        ;;
    *)
        echo "Tipo: URL"
        firefox --kiosk "$URL" &
        ;;
esac

# Verificar se o Firefox abriu
sleep 5
if pgrep -f firefox > /dev/null; then
    echo "✓ Firefox iniciado com sucesso!"
    echo "Kiosk rodando em modo tela cheia"
    echo ""
    echo "Para parar:"
    echo "  pkill -f firefox"
    echo "  Ctrl+C nesta janela"
    echo ""
    echo "Aguardando..."
    
    # Manter script rodando
    while pgrep -f firefox > /dev/null; do
        sleep 1
    done
    
    echo "Firefox fechado"
else
    echo "✗ Falha ao iniciar Firefox"
    echo "Verificando:"
    echo "  Firefox instalado: $(which firefox)"
    echo "  Display: $DISPLAY"
    echo "  Usuario: $(whoami)"
    echo "  Sessao X11: $(ps aux | grep X | grep -v grep)"
fi

echo "Kiosk finalizado"
