#!/bin/bash

# Script simples para kiosk que abre URLs em janelas separadas
# e rotaciona entre elas usando Alt+Tab

echo "Iniciando CrediVision Simple Kiosk..."

# Verificar dependências
if ! command -v firefox &> /dev/null; then
    echo "ERRO: Firefox não está instalado!"
    echo "Instale com: sudo apt install firefox"
    exit 1
fi

if ! command -v xdotool &> /dev/null; then
    echo "ERRO: xdotool não está instalado!"
    echo "Instale com: sudo apt install xdotool"
    exit 1
fi

# Verificar aplicação
if ! curl -s http://localhost:5000/api/config > /dev/null; then
    echo "ERRO: Aplicação CrediVision não está respondendo!"
    exit 1
fi

# Diretório temporário
TEMP_DIR="/tmp/credivision_kiosk_$$"
mkdir -p "$TEMP_DIR"

# Obter configuração
CONFIG_FILE="$TEMP_DIR/config.json"
curl -s http://localhost:5000/api/config > "$CONFIG_FILE"

# Processar URLs e criar arquivos HTML locais
echo "Processando abas..."
python3 << EOF
import json
import os

with open('$CONFIG_FILE') as f:
    data = json.load(f)

urls = []
for i, tab in enumerate(data.get('tabs', [])):
    if not tab.get('active', True):
        continue
    
    name = tab.get('name', f'Aba {i+1}')
    url = tab.get('url', '')
    content_type = tab.get('content_type', 'url')
    duration = tab.get('duration', 300)
    
    if content_type == 'url':
        urls.append((url, name, duration))
    elif content_type == 'image':
        # Criar página HTML para imagem
        html = f'''<!DOCTYPE html>
<html>
<head>
    <title>{name}</title>
    <style>
        body {{ margin: 0; padding: 0; background: #000; display: flex; align-items: center; justify-content: center; height: 100vh; }}
        img {{ max-width: 100%; max-height: 100vh; object-fit: contain; }}
    </style>
</head>
<body>
    <img src="{url}" alt="{name}">
</body>
</html>'''
        html_file = f'$TEMP_DIR/image_{i}.html'
        with open(html_file, 'w') as f:
            f.write(html)
        urls.append((f'file://{html_file}', name, duration))
        
    elif content_type == 'video':
        # Criar página HTML para vídeo
        html = f'''<!DOCTYPE html>
<html>
<head>
    <title>{name}</title>
    <style>
        body {{ margin: 0; padding: 0; background: #000; display: flex; align-items: center; justify-content: center; height: 100vh; }}
        video {{ max-width: 100%; max-height: 100vh; object-fit: contain; }}
    </style>
</head>
<body>
    <video autoplay muted loop>
        <source src="{url}">
        Seu navegador não suporta vídeo.
    </video>
</body>
</html>'''
        html_file = f'$TEMP_DIR/video_{i}.html'
        with open(html_file, 'w') as f:
            f.write(html)
        urls.append((f'file://{html_file}', name, duration))

# Salvar lista de URLs
with open('$TEMP_DIR/urls.txt', 'w') as f:
    for url, name, duration in urls:
        f.write(f'{url}|{name}|{duration}\n')

print(f'Processadas {len(urls)} abas')
EOF

# Verificar se há URLs
if [ ! -s "$TEMP_DIR/urls.txt" ]; then
    echo "ERRO: Nenhuma aba válida encontrada!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Ler URLs
declare -a URLS
declare -a NAMES
declare -a DURATIONS

i=0
while IFS='|' read -r url name duration; do
    URLS[$i]="$url"
    NAMES[$i]="$name"
    DURATIONS[$i]="$duration"
    ((i++))
done < "$TEMP_DIR/urls.txt"

echo "Encontradas ${#URLS[@]} abas para exibir"

# Fechar janelas Firefox existentes
echo "Fechando janelas Firefox anteriores..."
pkill -f "firefox" || true
sleep 2

# Abrir cada URL em sua própria janela
echo "Abrindo janelas Firefox..."
WINDOW_IDS=()

for i in "${!URLS[@]}"; do
    echo "Abrindo: ${NAMES[$i]}"
    
    case "${1:-normal}" in
        "debug")
            firefox --new-window --width=1280 --height=720 "${URLS[$i]}" &
            ;;
        "fullscreen")
            firefox --kiosk --fullscreen "${URLS[$i]}" &
            ;;
        *)
            firefox --kiosk "${URLS[$i]}" &
            ;;
    esac
    
    # Aguardar janela abrir
    sleep 2
    
    # Obter ID da janela
    WINDOW_ID=$(xdotool search --class "firefox" | tail -1)
    WINDOW_IDS[$i]="$WINDOW_ID"
    
    # Mover janela para posição específica (opcional)
    if [ "${1:-normal}" = "debug" ]; then
        xdotool windowmove "$WINDOW_ID" $((i * 50)) $((i * 50))
    fi
done

# Aguardar todas as janelas carregarem
sleep 5

# Função de rotação
rotate_windows() {
    local current=0
    local count=${#WINDOW_IDS[@]}
    
    echo "Iniciando rotação de $count janelas..."
    
    while true; do
        # Ativar janela atual
        window_id=${WINDOW_IDS[$current]}
        name=${NAMES[$current]}
        
        echo "Exibindo: $name"
        xdotool windowactivate "$window_id"
        
        # Mostrar notificação (opcional)
        if command -v notify-send &> /dev/null; then
            notify-send "CrediVision" "Aba: $name" &
        fi
        
        # Aguardar duração da aba
        duration=${DURATIONS[$current]}
        echo "Aguardando $duration segundos..."
        sleep $duration
        
        # Próxima janela
        current=$(( (current + 1) % count ))
    done
}

# Iniciar rotação em background
rotate_windows &
ROTATION_PID=$!

echo "Kiosk iniciado!"
echo "Janelas: ${#WINDOW_IDS[@]}"
echo "Rotação PID: $ROTATION_PID"
echo ""
echo "Para parar:"
echo "  kill $ROTATION_PID"
echo "  pkill -f simple_kiosk.sh"
echo ""
echo "Atalhos:"
echo "  Ctrl+Alt+X: Parar rotação"
echo ""

# Configurar atalho para parar
xdotool key --delay 0 Alt+F4 &
# Na verdade, vamos criar um script de parada
cat > "$TEMP_DIR/stop.sh" << EOF
#!/bin/bash
kill $ROTATION_PID 2>/dev/null
pkill -f firefox
echo "Kiosk parado"
EOF
chmod +x "$TEMP_DIR/stop.sh"

echo "Para parar o kiosk, execute:"
echo "  $TEMP_DIR/stop.sh"

# Limpar ao sair
trap "echo 'Limpando...'; kill \$ROTATION_PID 2>/dev/null; pkill -f firefox; rm -rf '$TEMP_DIR'" EXIT

# Aguardar
wait $ROTATION_PID
