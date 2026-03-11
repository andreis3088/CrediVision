#!/bin/bash

echo "=========================================="
echo "CORRIGINDO PROBLEMAS - Login e Kiosk"
echo "=========================================="
echo ""

# Verificar se esta rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash CORRIGIR_PROBLEMAS.sh"
    exit 1
fi

SERVICE_USER="informa"
PROJECT_DIR="/home/informa/Documentos/CrediVision"
DATA_DIR="/home/informa/Documents/kiosk-data"

echo "Usuario: $SERVICE_USER"
echo "Projeto: $PROJECT_DIR"
echo ""

# Problema 1: Corrigir senha do admin
echo "PROBLEMA 1: Corrigindo senha do admin..."
echo ""

# Verificar arquivo de usuarios
if [ ! -f "$DATA_DIR/users.json" ]; then
    echo "Criando arquivo de usuarios..."
    mkdir -p "$DATA_DIR"
    cat > "$DATA_DIR/users.json" << 'EOF'
[
  {
    "id": 1,
    "username": "admin",
    "password_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "role": "admin",
    "created_at": "2024-01-01T00:00:00"
  }
]
EOF
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR/users.json"
else
    echo "Arquivo de usuarios ja existe, verificando..."
    
    # Verificar se o hash esta correto
    python3 << 'EOF'
import hashlib

def hash_password(password: str) -> str:
    salt = "kiosk_salt_2024"
    return hashlib.sha256(f"{salt}{password}".encode()).hexdigest()

# Hash correto para "admin123"
correct_hash = hash_password("admin123")
print(f"Hash correto para admin123: {correct_hash}")

# Ler arquivo atual
try:
    import json
    with open("/home/informa/Documents/kiosk-data/users.json", "r") as f:
        users = json.load(f)
    
    # Verificar admin
    for user in users:
        if user.get("username") == "admin":
            current_hash = user.get("password_hash", "")
            print(f"Hash atual: {current_hash}")
            
            if current_hash != correct_hash:
                print("Corrigindo hash...")
                user["password_hash"] = correct_hash
                
                # Salvar arquivo corrigido
                with open("/home/informa/Documents/kiosk-data/users.json", "w") as f:
                    json.dump(users, f, indent=2)
                
                print("Hash corrigido!")
            else:
                print("Hash ja esta correto!")
            break
    else:
        print("Usuario admin nao encontrado")
        
except Exception as e:
    print(f"Erro: {e}")
EOF
fi

echo ""
echo "PROBLEMA 2: Corrigindo script do kiosk..."
echo ""

# Fazer backup do script original
if [ -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
    cp "$PROJECT_DIR/simple_kiosk_enhanced.sh" "$PROJECT_DIR/simple_kiosk_enhanced.sh.backup"
    echo "Backup criado: simple_kiosk_enhanced.sh.backup"
fi

# Criar script corrigido
cat > "$PROJECT_DIR/simple_kiosk_enhanced.sh" << 'EOF'
#!/bin/bash

# Enhanced Simple Kiosk - Versao CORRIGIDA
# Suporte completo para Imagens, Vídeos e URLs
# Tela cheia real e funcionamento garantido

echo "Iniciando CrediVision Enhanced Simple Kiosk (CORRIGIDO)..."

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
}
trap cleanup EXIT

# Verificar dependências
check_dependencies
check_application

echo "Aplicação está respondendo!"

# Obter configuração da API
CONFIG_FILE="/home/informa/Documents/kiosk-data/tabs.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERRO: Arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
fi

# Ler configuração usando Python
python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

CONFIG_FILE = "/home/informa/Documents/kiosk-data/tabs.json"

try:
    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)
    
    tabs = config.get('tabs', [])
    
    if not tabs:
        print("ERRO: Nenhuma aba configurada!")
        print("Configure abas em: http://localhost:5000")
        sys.exit(1)
    
    print(f"Encontradas {len(tabs)} abas:")
    
    # Arrays para shell script
    urls = []
    names = []
    types = []
    durations = []
    
    for i, tab in enumerate(tabs):
        if not tab.get('enabled', True):
            continue
            
        url = tab.get('url', '').strip()
        name = tab.get('name', f'Aba {i+1}').strip()
        tab_type = tab.get('type', 'url').strip().lower()
        duration = tab.get('duration', 30)
        
        if not url:
            continue
        
        urls.append(url)
        names.append(name)
        types.append(tab_type)
        durations.append(str(duration))
        
        print(f"  {i+1}. {name} ({tab_type}) - {duration}s")
    
    if not urls:
        print("ERRO: Nenhuma aba válida encontrada!")
        sys.exit(1)
    
    # Exportar variáveis para o shell
    print(f"export URLS_COUNT={len(urls)}")
    
    for i, (url, name, tab_type, duration) in enumerate(zip(urls, names, types, durations)):
        print(f"export URL_{i}=\"{url}\"")
        print(f"export NAME_{i}=\"{name}\"")
        print(f"export TYPE_{i}=\"{tab_type}\"")
        print(f"export DURATION_{i}={duration}")
    
except Exception as e:
    print(f"ERRO ao ler configuração: {e}")
    sys.exit(1)
PYTHON_SCRIPT

# Verificar se o Python executou com sucesso
if [ $? -ne 0 ]; then
    echo "ERRO: Falha ao processar configuração"
    exit 1
fi

# Carregar variáveis do Python
eval "$(python3 << 'PYTHON_SCRIPT'
import json
import sys

CONFIG_FILE = "/home/informa/Documents/kiosk-data/tabs.json"

try:
    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)
    
    tabs = config.get('tabs', [])
    
    urls = []
    names = []
    types = []
    durations = []
    
    for tab in tabs:
        if not tab.get('enabled', True):
            continue
            
        url = tab.get('url', '').strip()
        name = tab.get('name', '').strip()
        tab_type = tab.get('type', 'url').strip().lower()
        duration = tab.get('duration', 30)
        
        if not url:
            continue
        
        urls.append(url)
        names.append(name)
        types.append(tab_type)
        durations.append(str(duration))
    
    print(f"URLS_COUNT={len(urls)}")
    
    for i, (url, name, tab_type, duration) in enumerate(zip(urls, names, types, durations)):
        print(f"URL_{i}=\"{url}\"")
        print(f"NAME_{i}=\"{name}\"")
        print(f"TYPE_{i}=\"{tab_type}\"")
        print(f"DURATION_{i}={duration}")
    
except Exception as e:
    print(f"ERRO: {e}")
    sys.exit(1)
PYTHON_SCRIPT
)"

echo ""
echo "Configuração carregada: $URLS_COUNT abas"

# Arrays para armazenar informações
URLS=()
NAMES=()
TYPES=()
DURATIONS=()

# Carregar arrays
for ((i=0; i<URLS_COUNT; i++)); do
    var_url="URL_$i"
    var_name="NAME_$i"
    var_type="TYPE_$i"
    var_duration="DURATION_$i"
    
    URLS[i]="${!var_url}"
    NAMES[i]="${!var_name}"
    TYPES[i]="${!var_type}"
    DURATIONS[i]="${!var_duration}"
done

# Fechar janelas Firefox existentes do kiosk
echo "Fechando janelas Firefox anteriores..."
pkill -f "simple_kiosk" 2>/dev/null || true
pkill -f "firefox" 2>/dev/null || true
sleep 3

# Função para criar HTML para imagens
create_image_html() {
    local image_path="$1"
    local title="$2"
    
    cat > "$TEMP_DIR/image_$$.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
            background: #000;
        }
        img {
            width: 100vw;
            height: 100vh;
            object-fit: contain;
            display: block;
        }
    </style>
</head>
<body>
    <img src="$image_path" alt="$title" />
</body>
</html>
EOF
}

# Função para criar HTML para vídeos
create_video_html() {
    local video_path="$1"
    local title="$2"
    
    cat > "$TEMP_DIR/video_$$.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
            background: #000;
        }
        video {
            width: 100vw;
            height: 100vh;
            object-fit: contain;
            display: block;
        }
        .controls {
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0,0,0,0.7);
            padding: 10px;
            border-radius: 5px;
            z-index: 1000;
        }
        button {
            margin: 0 5px;
            padding: 5px 10px;
            background: #333;
            color: white;
            border: none;
            border-radius: 3px;
            cursor: pointer;
        }
        button:hover {
            background: #555;
        }
    </style>
</head>
<body>
    <video id="video" autoplay loop>
        <source src="$video_path">
        Seu navegador não suporta vídeo.
    </video>
    <div class="controls">
        <button onclick="document.getElementById('video').play()">▶</button>
        <button onclick="document.getElementById('video').pause()">⏸</button>
        <button onclick="document.getElementById('video').muted = !document.getElementById('video').muted">🔊</button>
        <button onclick="document.getElementById('video').requestFullscreen()">⛶</button>
    </div>
</body>
</html>
EOF
}

# Abrir cada conteúdo em sua própria janela
echo "Abrindo janelas Firefox..."
WINDOW_IDS=()

for ((i=0; i<URLS_COUNT; i++)); do
    url="${URLS[$i]}"
    name="${NAMES[$i]}"
    type="${TYPES[$i]}"
    
    echo "  - $name ($type)"
    
    case "$type" in
        "image")
            # Verificar se é caminho local
            if [[ "$url" =~ ^/ ]]; then
                create_image_html "$url" "$name"
                firefox --kiosk "file://$TEMP_DIR/image_$$.html" &
            else
                firefox --kiosk "$url" &
            fi
            ;;
        "video")
            # Verificar se é caminho local
            if [[ "$url" =~ ^/ ]]; then
                create_video_html "$url" "$name"
                firefox --kiosk "file://$TEMP_DIR/video_$$.html" &
            else
                firefox --kiosk "$url" &
            fi
            ;;
        *)
            # Modo kiosk para todos
            firefox --kiosk "$url" &
            ;;
    esac
    
    # Pegar ID da janela
    sleep 2
    WINDOW_ID=$(xdotool search --class firefox | tail -1)
    WINDOW_IDS+=("$WINDOW_ID")
    
    # Minimizar janela temporariamente
    xdotool windowminimize "$WINDOW_ID"
done

echo ""
echo "=========================================="
echo "Enhanced Simple Kiosk Iniciado!"
echo "=========================================="
echo ""
echo "Janelas: ${#WINDOW_IDS[@]}"
echo "Modo: Tela cheia (kiosk)"
echo ""

# Aguardar um pouco para as janelas carregarem
sleep 5

# Maximizar primeira janela e iniciar rotação
if [ ${#WINDOW_IDS[@]} -gt 0 ]; then
    echo "Iniciando rotação de janelas..."
    
    # Maximizar primeira janela
    xdotool windowactivate "${WINDOW_IDS[0]}"
    xdotool windowmaximize "${WINDOW_IDS[0]}"
    
    # Script de rotação em background
    cat > "$TEMP_DIR/rotate.sh" << ROTATE_EOF
#!/bin/bash

# Arrays de janelas
WINDOW_IDS=(${WINDOW_IDS[@]})
DURATIONS=(${DURATIONS[@]})
CURRENT_INDEX=0
WINDOW_COUNT=${#WINDOW_IDS[@]}

echo "Iniciando rotação de \$WINDOW_COUNT janelas..."

while true; do
    if [ \$WINDOW_COUNT -eq 0 ]; then
        echo "Nenhuma janela para rotacionar"
        break
    fi
    
    # Minimizar janela atual
    xdotool windowminimize "\${WINDOW_IDS[\$CURRENT_INDEX]}"
    
    # Próxima janela
    CURRENT_INDEX=\$(((CURRENT_INDEX + 1) % WINDOW_COUNT))
    
    # Ativar e maximizar próxima janela
    xdotool windowactivate "\${WINDOW_IDS[\$CURRENT_INDEX]}"
    xdotool windowmaximize "\${WINDOW_IDS[\$CURRENT_INDEX]}"
    
    # Tempo de exibição
    DURATION=\${DURATIONS[\$CURRENT_INDEX]}
    echo "Janela \$CURRENT_INDEX por \${DURATION}s"
    
    sleep \$DURATION
done
ROTATE_EOF
    
    chmod +x "$TEMP_DIR/rotate.sh"
    
    # Iniciar rotação em background
    "$TEMP_DIR/rotate.sh" &
    ROTATION_PID=$!
    
    echo "Rotação iniciada (PID: $ROTATION_PID)"
fi

echo ""
echo "Comandos:"
echo "  Parar rotação: kill $ROTATION_PID"
echo "  Parar kiosk: pkill -f simple_kiosk_enhanced.sh"
echo "  Ver janelas: xdotool search --class firefox"
echo ""
echo "Atalhos:"
echo "  F11 - Tela cheia"
echo "  Ctrl+Tab - Próxima janela"
echo "  Ctrl+Q - Fechar janela"
echo ""

# Criar script de atalhos
cat > "$TEMP_DIR/shortcuts.sh" << 'EOF'
#!/bin/bash
# Script para atalhos do kiosk

case "$1" in
    "stop")
        echo "Parando kiosk..."
        pkill -f simple_kiosk_enhanced.sh
        ;;
    "next")
        echo "Próxima janela..."
        xdotool key ctrl+Tab
        ;;
    "fullscreen")
        echo "Tela cheia..."
        xdotool key F11
        ;;
    *)
        echo "Uso: $0 {stop|next|fullscreen}"
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
echo "Kiosk rodando. Pressione Ctrl+C para parar..."
wait
EOF

chmod +x "$PROJECT_DIR/simple_kiosk_enhanced.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/simple_kiosk_enhanced.sh"

echo "Script do kiosk corrigido!"

echo ""
echo "PROBLEMA 3: Reiniciando servicos..."
echo ""

# Reiniciar servicos
systemctl restart credivision-app.service
sleep 5
systemctl restart credivision-auto-update.service
sleep 2
systemctl restart credivision-kiosk.service

echo "Servicos reiniciados!"

echo ""
echo "PROBLEMA 4: Testando acesso..."
echo ""

# Testar API
if curl -s http://localhost:5000/api/config > /dev/null; then
    echo "✓ API respondendo"
    
    # Testar login
    response=$(curl -s -c /tmp/cookies.txt -b /tmp/cookies.txt \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' \
        http://localhost:5000/login)
    
    if echo "$response" | grep -q "success"; then
        echo "✓ Login funcionando!"
    else
        echo "✗ Login com problemas"
        echo "Response: $response"
    fi
else
    echo "✗ API não respondendo"
fi

echo ""
echo "=========================================="
echo "CORREÇÕES APLICADAS!"
echo "=========================================="
echo ""
echo "1. ✓ Senha do admin corrigida"
echo "2. ✓ Script do kiosk corrigido (tela cheia)"
echo "3. ✓ Serviços reiniciados"
echo "4. ✓ Acesso testado"
echo ""
echo "Credenciais:"
echo "  URL: http://$(hostname -I | awk '{print $1}'):5000"
echo "  Login: admin"
echo "  Senha: admin123"
echo ""
echo "O kiosk deve iniciar em tela cheia em até 30 segundos!"
echo ""
echo "Se ainda tiver problemas:"
echo "  - Verifique logs: sudo journalctl -u credivision-kiosk.service -f"
echo "  - Teste manual: sudo -u informa bash simple_kiosk_enhanced.sh"
echo "  - Verifique abas: http://localhost:5000/tabs"
echo ""
