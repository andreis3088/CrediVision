#!/bin/bash

# Enhanced Simple Kiosk - Suporte completo para Imagens, Vídeos e URLs
# Abre cada conteúdo em janela separada do Firefox

echo "Iniciando CrediVision Enhanced Simple Kiosk..."

# Verificar dependências
check_dependencies() {
    local missing=()
    
    if ! command -v firefox &> /dev/null; then
        missing+=("firefox")
    fi
    
    if ! command -v xdotool &> /dev/null; then
        missing+=("xdotool")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERRO: Dependências faltando: ${missing[*]}"
        echo "Instale com: sudo apt install ${missing[*]}"
        exit 1
    fi
}

# Verificar aplicação
check_application() {
    if ! curl -s http://localhost:5000/api/config > /dev/null; then
        echo "ERRO: Aplicação CrediVision não está respondendo!"
        echo "Verifique: sudo systemctl status credivision-app.service"
        exit 1
    fi
}

# Criar diretório temporário
TEMP_DIR="/tmp/credivision_kiosk_$$"
mkdir -p "$TEMP_DIR"

# Função de limpeza
cleanup() {
    echo "Limpando arquivos temporários..."
    rm -rf "$TEMP_DIR"
    # Não matar Firefox aqui para não interromper outras instâncias
}
trap cleanup EXIT

# Verificar dependências
check_dependencies
check_application

# Obter configuração
CONFIG_FILE="$TEMP_DIR/config.json"
echo "Buscando configuração da API..."
curl -s http://localhost:5000/api/config > "$CONFIG_FILE"

# Processar conteúdo e criar arquivos HTML locais
echo "Processando abas..."
python3 << EOF
import json
import os
import urllib.parse

def create_image_html(url, name):
    """Criar HTML para exibição de imagem"""
    return f'''<!DOCTYPE html>
<html>
<head>
    <title>{name}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ 
            background: #000; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            height: 100vh; 
            overflow: hidden;
        }}
        .container {{
            position: relative;
            max-width: 100vw;
            max-height: 100vh;
        }}
        img {{ 
            max-width: 100vw; 
            max-height: 100vh; 
            object-fit: contain; 
            display: block;
        }}
        .info {{
            position: absolute;
            top: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 10px 15px;
            border-radius: 8px;
            font-family: Arial, sans-serif;
            font-size: 14px;
            backdrop-filter: blur(10px);
            opacity: 0;
            transition: opacity 0.3s;
        }}
        .info:hover {{
            opacity: 1;
        }}
    </style>
</head>
<body>
    <div class="container">
        <img src="{url}" alt="{name}" onload="this.style.opacity='1'">
        <div class="info">{name}</div>
    </div>
</body>
</html>'''

def create_video_html(url, name):
    """Criar HTML para exibição de vídeo"""
    return f'''<!DOCTYPE html>
<html>
<head>
    <title>{name}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ 
            background: #000; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            height: 100vh; 
            overflow: hidden;
        }}
        .container {{
            position: relative;
            max-width: 100vw;
            max-height: 100vh;
        }}
        video {{ 
            max-width: 100vw; 
            max-height: 100vh; 
            object-fit: contain; 
            display: block;
        }}
        .info {{
            position: absolute;
            top: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 10px 15px;
            border-radius: 8px;
            font-family: Arial, sans-serif;
            font-size: 14px;
            backdrop-filter: blur(10px);
            opacity: 0;
            transition: opacity 0.3s;
        }}
        .info:hover {{
            opacity: 1;
        }}
        .controls {{
            position: absolute;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0, 0, 0, 0.7);
            padding: 10px 20px;
            border-radius: 25px;
            backdrop-filter: blur(10px);
            display: flex;
            gap: 15px;
            align-items: center;
        }}
        .controls button {{
            background: rgba(255, 255, 255, 0.2);
            border: none;
            color: white;
            padding: 8px 12px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }}
        .controls button:hover {{
            background: rgba(255, 255, 255, 0.3);
        }}
    </style>
</head>
<body>
    <div class="container">
        <video id="video" autoplay muted loop playsinline>
            <source src="{url}">
            Seu navegador não suporta este formato de vídeo.
        </video>
        <div class="info">{name}</div>
        <div class="controls">
            <button onclick="document.getElementById('video').play()">▶</button>
            <button onclick="document.getElementById('video').pause()">⏸</button>
            <button onclick="document.getElementById('video').muted = !document.getElementById('video').muted">🔊</button>
            <button onclick="document.getElementById('video').fullscreen()">⛶</button>
        </div>
    </div>
</body>
</html>'''

def create_url_html(url, name):
    """Criar HTML para redirecionamento de URL"""
    return f'''<!DOCTYPE html>
<html>
<head>
    <title>{name}</title>
    <meta http-equiv="refresh" content="0; url={url}">
    <style>
        body {{
            background: #000;
            color: white;
            font-family: Arial, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }}
        .loading {{
            text-align: center;
        }}
        .spinner {{
            border: 3px solid rgba(255, 255, 255, 0.1);
            border-top: 3px solid #00AE9D;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }}
        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}
    </style>
</head>
<body>
    <div class="loading">
        <div class="spinner"></div>
        <h2>Carregando {name}</h2>
        <p>Redirecionando para o site...</p>
    </div>
</body>
</html>'''

# Carregar configuração
with open('$CONFIG_FILE') as f:
    data = json.load(f)

tabs = data.get('tabs', [])
active_tabs = [tab for tab in tabs if tab.get('active', True)]

if not active_tabs:
    print("ERRO: Nenhuma aba ativa encontrada!")
    exit(1)

urls = []
for i, tab in enumerate(active_tabs):
    name = tab.get('name', f'Aba {i+1}')
    url = tab.get('url', '')
    content_type = tab.get('content_type', 'url')
    duration = tab.get('duration', 300)
    
    print(f"Processando: {name} ({content_type})")
    
    if content_type == 'url':
        # Para URLs, usar diretamente no Firefox
        urls.append((url, name, duration, 'url'))
        
    elif content_type == 'image':
        # Criar página HTML para imagem
        html = create_image_html(url, name)
        html_file = f'$TEMP_DIR/image_{i}.html'
        with open(html_file, 'w') as f:
            f.write(html)
        urls.append((f'file://{html_file}', name, duration, 'image'))
        
    elif content_type == 'video':
        # Criar página HTML para vídeo
        html = create_video_html(url, name)
        html_file = f'$TEMP_DIR/video_{i}.html'
        with open(html_file, 'w') as f:
            f.write(html)
        urls.append((f'file://{html_file}', name, duration, 'video'))

# Salvar lista de URLs com tipo
with open('$TEMP_DIR/urls.txt', 'w') as f:
    for url, name, duration, content_type in urls:
        f.write(f'{url}|{name}|{duration}|{content_type}\n')

print(f'Processadas {len(urls)} abas ativas')
print("Tipos:", [u[3] for u in urls])
EOF

# Verificar se há URLs
if [ ! -s "$TEMP_DIR/urls.txt" ]; then
    echo "ERRO: Nenhuma aba válida encontrada!"
    exit 1
fi

# Ler URLs
declare -a URLS
declare -a NAMES
declare -a DURATIONS
declare -a TYPES

i=0
while IFS='|' read -r url name duration content_type; do
    URLS[$i]="$url"
    NAMES[$i]="$name"
    DURATIONS[$i]="$duration"
    TYPES[$i]="$content_type"
    ((i++))
done < "$TEMP_DIR/urls.txt"

echo "Encontradas ${#URLS[@]} abas para exibir:"
for i in "${!URLS[@]}"; do
    echo "  - ${NAMES[$i]} (${TYPES[$i]})"
done

# Fechar janelas Firefox existentes do kiosk
echo "Fechando janelas Firefox anteriores..."
pkill -f "simple_kiosk" 2>/dev/null || true
sleep 2

# Abrir cada conteúdo em sua própria janela
echo "Abrindo janelas Firefox..."
WINDOW_IDS=()

for i in "${!URLS[@]}"; do
    url="${URLS[$i]}"
    name="${NAMES[$i]}"
    content_type="${TYPES[$i]}"
    
    echo "Abrindo: $name ($content_type)"
    
    # Configurar modo based no tipo e parâmetro
    case "${1:-normal}" in
        "debug")
            if [ "$content_type" = "url" ]; then
                firefox --new-window --width=1280 --height=720 "$url" &
            else
                firefox --new-window --width=1280 --height=720 "$url" &
            fi
            ;;
        "window")
            firefox --new-window --width=1280 --height=720 "$url" &
            ;;
        *)
            # Modo kiosk para todos
            firefox --kiosk "$url" &
            ;;
    esac
    
    # Aguardar janela abrir
    sleep 2
    
    # Obter ID da janela mais recente
    WINDOW_ID=$(xdotool search --class "firefox" | tail -1)
    WINDOW_IDS[$i]="$WINDOW_ID"
    
    # Configurar posição em modo debug
    if [ "${1:-normal}" = "debug" ]; then
        xdotool windowmove "$WINDOW_ID" $((i * 50)) $((i * 50))
    fi
    
    # Pequeno delay entre aberturas
    sleep 1
done

# Aguardar todas as janelas carregarem
echo "Aguardando carregamento das janelas..."
sleep 5

# Função de rotação melhorada
rotate_windows() {
    local current=0
    local count=${#WINDOW_IDS[@]}
    
    echo "Iniciando rotação de $count janelas..."
    
    while true; do
        # Ativar janela atual
        window_id=${WINDOW_IDS[$current]}
        name=${NAMES[$current]}
        content_type=${TYPES[$current]}
        
        echo "Exibindo: $name ($content_type)"
        
        # Trazer janela para frente
        xdotool windowactivate "$window_id"
        
        # Mostrar notificação
        if command -v notify-send &> /dev/null; then
            notify-send "CrediVision" "Aba: $name" &
        fi
        
        # Para vídeos, garantir que estão reproduzindo
        if [ "$content_type" = "video" ]; then
            # Enviar comando de play (se necessário)
            xdotool key --window "$window_id" "space"
        fi
        
        # Aguardar duração da aba
        duration=${DURATIONS[$current]}
        echo "Aguardando $duration segundos..."
        
        # Contador regressivo (opcional)
        for ((sec=duration; sec>0; sec--)); do
            if [ $((sec % 30)) -eq 0 ] || [ $sec -le 5 ]; then
                echo "  $seg segundos restantes..."
            fi
            sleep 1
        done
        
        # Próxima janela
        current=$(( (current + 1) % count ))
    done
}

# Iniciar rotação em background
rotate_windows &
ROTATION_PID=$!

echo ""
echo "=========================================="
echo "Enhanced Simple Kiosk Iniciado!"
echo "=========================================="
echo ""
echo "Janelas: ${#WINDOW_IDS[@]}"
echo "Rotação PID: $ROTATION_PID"
echo ""
echo "Conteúdo:"
for i in "${!URLS[@]}"; do
    echo "  ${NAMES[$i]} - ${TYPES[$i]}"
done
echo ""
echo "Comandos:"
echo "  Parar rotação: kill $ROTATION_PID"
echo "  Parar kiosk: pkill -f simple_kiosk_enhanced.sh"
echo "  Ver janelas: xdotool search --class firefox"
echo ""
echo "Atalhos:"
echo "  Ctrl+Alt+X: Parar rotação"
echo "  Ctrl+Alt+N: Próxima aba"
echo ""

# Configurar atalhos de teclado
# Criar script de atalhos
cat > "$TEMP_DIR/shortcuts.sh" << 'EOF'
#!/bin/bash
# Script para atalhos do kiosk

case "$1" in
    "stop")
        echo "Parando rotação..."
        kill $ROTATION_PID 2>/dev/null
        ;;
    "next")
        echo "Próxima aba..."
        # Implementar lógica de próxima aba
        ;;
esac
EOF
chmod +x "$TEMP_DIR/shortcuts.sh"

# Script de parada
cat > "$TEMP_DIR/stop.sh" << EOF
#!/bin/bash
echo "Parando Enhanced Simple Kiosk..."
kill $ROTATION_PID 2>/dev/null
pkill -f simple_kiosk_enhanced.sh 2>/dev/null
echo "Kiosk parado"
EOF
chmod +x "$TEMP_DIR/stop.sh"

echo "Para parar o kiosk, execute:"
echo "  $TEMP_DIR/stop.sh"

# Aguardar
wait $ROTATION_PID
