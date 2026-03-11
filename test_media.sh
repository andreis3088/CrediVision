#!/bin/bash

# Script para testar suporte a imagens e vídeos no Simple Kiosk

echo "=========================================="
echo "Teste de Mídia - CrediVision Simple Kiosk"
echo "=========================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Verificar se aplicação está rodando
if ! curl -s http://localhost:5000/api/config > /dev/null; then
    log_error "Aplicação não está respondendo!"
    echo "Inicie a aplicação primeiro:"
    echo "  sudo systemctl start credivision-app.service"
    exit 1
fi

# Criar diretório de teste
TEST_DIR="/tmp/credivision_test_$$"
mkdir -p "$TEST_DIR"

# Função de limpeza
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Criar imagem de teste
create_test_image() {
    log_info "Criando imagem de teste..."
    
    # Criar SVG simples
    cat > "$TEST_DIR/test_image.svg" << 'EOF'
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#1a1a2e"/>
  <text x="400" y="300" font-family="Arial" font-size="48" fill="#00AE9D" text-anchor="middle">
    IMAGEM DE TESTE
  </text>
  <text x="400" y="350" font-family="Arial" font-size="24" fill="#ffffff" text-anchor="middle">
    CrediVision - Simple Kiosk
  </text>
  <circle cx="400" cy="450" r="50" fill="#ff6b6b"/>
</svg>
EOF
    
    echo "Imagem criada: $TEST_DIR/test_image.svg"
}

# Criar vídeo de teste (se possível)
create_test_video() {
    log_info "Verificando se podemos criar vídeo de teste..."
    
    # Tentar criar vídeo simples com ffmpeg (se disponível)
    if command -v ffmpeg &> /dev/null; then
        log_info "Criando vídeo de teste com ffmpeg..."
        ffmpeg -f lavfi -i "testsrc=size=800x600:duration=10:rate=30" \
               -vf "drawtext=text='VÍDEO DE TESTE':fontsize=48:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
               -c:v libx264 -t 10 "$TEST_DIR/test_video.mp4" -y 2>/dev/null
        
        if [ -f "$TEST_DIR/test_video.mp4" ]; then
            echo "Vídeo criado: $TEST_DIR/test_video.mp4"
            return 0
        fi
    fi
    
    log_warn "ffmpeg não disponível, criando HTML de vídeo simulado..."
    
    # Criar HTML que simula vídeo
    cat > "$TEST_DIR/test_video.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Vídeo de Teste</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #1a1a2e;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            font-family: Arial, sans-serif;
        }
        .video-container {
            text-align: center;
        }
        .video-placeholder {
            width: 800px;
            height: 600px;
            background: linear-gradient(45deg, #ff6b6b, #00AE9D);
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 10px;
            color: white;
            font-size: 48px;
            margin-bottom: 20px;
        }
        .info {
            color: white;
            font-size: 24px;
        }
    </style>
</head>
<body>
    <div class="video-container">
        <div class="video-placeholder">
            ▶ VÍDEO TESTE
        </div>
        <div class="info">
            Simulação de vídeo - CrediVision
        </div>
    </div>
</body>
</html>
EOF
    
    echo "HTML de vídeo criado: $TEST_DIR/test_video.html"
}

# Adicionar abas de teste ao sistema
add_test_tabs() {
    log_info "Adicionando abas de teste..."
    
    # Obter configuração atual
    CONFIG_FILE="/tmp/current_config.json"
    curl -s http://localhost:5000/api/config > "$CONFIG_FILE"
    
    # Criar novas abas
    python3 << EOF
import json
import os

# Carregar configuração atual
with open('$CONFIG_FILE') as f:
    data = json.load(f)

tabs = data.get('tabs', [])

# Adicionar aba de imagem
image_tab = {
    'id': max([tab.get('id', 0) for tab in tabs], default=0) + 1,
    'name': 'IMAGEM TESTE',
    'url': 'file://$TEST_DIR/test_image.svg',
    'content_type': 'image',
    'duration': 10,
    'active': True,
    'created_at': '2024-01-01T00:00:00'
}

# Adicionar aba de vídeo
video_tab = {
    'id': max([tab.get('id', 0) for tab in tabs], default=0) + 2,
    'name': 'VÍDEO TESTE',
    'url': 'file://$TEST_DIR/test_video.html',
    'content_type': 'video',
    'duration': 15,
    'active': True,
    'created_at': '2024-01-01T00:00:00'
}

tabs.extend([image_tab, video_tab])

# Salvar nova configuração
with open('/tmp/new_tabs.json', 'w') as f:
    json.dump(tabs, f, indent=2, ensure_ascii=False)

print(f"Adicionadas {len([image_tab, video_tab])} abas de teste")
EOF
    
    # Atualizar abas no sistema
    log_info "Atualizando abas no sistema..."
    
    # Fazer upload das novas abas
    curl -X POST http://localhost:5000/api/tabs/batch \
         -H "Content-Type: application/json" \
         -d @/tmp/new_tabs.json 2>/dev/null || log_warn "Não foi possível atualizar abas automaticamente"
    
    log_info "Abas de teste adicionadas"
}

# Testar Simple Kiosk
test_simple_kiosk() {
    log_info "Testando Simple Kiosk com mídia..."
    
    echo ""
    echo "Iniciando Simple Kiosk em modo debug..."
    echo "Você deverá ver:"
    echo "  1. Janela com imagem SVG"
    echo "  2. Janela com vídeo/simulação"
    echo "  3. Rotação automática entre elas"
    echo ""
    echo "Pressione Ctrl+C para parar o teste"
    echo ""
    
    # Iniciar kiosk em modo debug
    cd "$(dirname "$0")"
    if [ -f "simple_kiosk_enhanced.sh" ]; then
        sudo -u "${SUDO_USER:-$USER}" ./simple_kiosk_enhanced.sh debug
    elif [ -f "simple_kiosk.sh" ]; then
        sudo -u "${SUDO_USER:-$USER}" ./simple_kiosk.sh debug
    else
        log_error "Script do kiosk não encontrado!"
        return 1
    fi
}

# Verificar suporte a formatos
check_format_support() {
    log_info "Verificando suporte a formatos..."
    
    echo ""
    echo "Formatos suportados:"
    echo "  Imagens: PNG, JPG, JPEG, GIF, SVG"
    echo "  Vídeos: MP4, AVI, MOV, WEBM"
    echo "  URLs: Qualquer site (sem restrições de iframe)"
    echo ""
    
    # Verificar Firefox
    if command -v firefox &> /dev/null; then
        echo "✓ Firefox: $(firefox --version)"
    else
        log_error "✗ Firefox não instalado"
    fi
    
    # Verificar xdotool
    if command -v xdotool &> /dev/null; then
        echo "✓ xdotool: $(xdotool --version)"
    else
        log_error "✗ xdotool não instalado"
    fi
    
    # Verificar Python
    if command -v python3 &> /dev/null; then
        echo "✓ Python3: $(python3 --version)"
    else
        log_error "✗ Python3 não instalado"
    fi
}

# Menu principal
case "${1:-all}" in
    "check")
        check_format_support
        ;;
    "create")
        create_test_image
        create_test_video
        ;;
    "add")
        create_test_image
        create_test_video
        add_test_tabs
        ;;
    "test")
        create_test_image
        create_test_video
        add_test_tabs
        test_simple_kiosk
        ;;
    "all")
        check_format_support
        create_test_image
        create_test_video
        add_test_tabs
        echo ""
        read -p "Deseja testar o kiosk agora? (S/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            test_simple_kiosk
        else
            echo "Para testar manualmente:"
            echo "  sudo bash test_media.sh test"
        fi
        ;;
    *)
        echo "Uso: $0 [check|create|add|test|all]"
        echo ""
        echo "Comandos:"
        echo "  check   - Verificar suporte a formatos"
        echo "  create  - Criar arquivos de teste"
        echo "  add     - Adicionar abas de teste"
        echo "  test    - Criar, adicionar e testar"
        echo "  all     - Executar tudo (padrão)"
        exit 1
        ;;
esac
