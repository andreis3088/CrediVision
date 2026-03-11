#!/bin/bash

# CrediVision Complete Installation Script - Simple Kiosk Version
# Único script para instalação completa do sistema

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${SUDO_USER:-$USER}"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"
APP_PORT="5000"
KIOSK_DELAY="30"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_header() {
    echo -e "${CYAN}=========================================="
    echo "$1"
    echo "==========================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute com sudo: sudo bash INSTALL_NEW.sh"
        exit 1
    fi
}

# Display banner
display_banner() {
    log_header "CrediVision - Simple Kiosk Installer"
    echo ""
    echo "Este script instala:"
    echo "  • Docker e Docker Compose"
    echo "  • Aplicação Flask CrediVision"
    echo "  • Simple Kiosk (sem iframe)"
    echo "  • Firefox com xdotool"
    echo "  • Serviços systemd"
    echo "  • Backup automático"
    echo ""
    echo "⚠️  Isso levará 10-15 minutos"
    echo ""
    read -p "Continuar? (S/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Cancelado."
        exit 0
    fi
}

# System requirements check
check_requirements() {
    log_step "Verificando requisitos do sistema..."
    
    # Check Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script é para Ubuntu"
        exit 1
    fi
    
    # Check user
    if ! id "$SERVICE_USER" &>/dev/null; then
        log_error "Usuário $SERVICE_USER não existe"
        exit 1
    fi
    
    # Check disk space
    available=$(df /home | awk 'NR==2 {print $4}')
    required=$((5 * 1024 * 1024)) # 5GB in KB
    
    if [ "$available" -lt "$required" ]; then
        log_error "Espaço em disco insuficiente (mínimo 5GB)"
        exit 1
    fi
    
    log_info "✓ Requisitos verificados"
}

# Update system
update_system() {
    log_step "Atualizando sistema..."
    apt update
    apt upgrade -y
    log_info "✓ Sistema atualizado"
}

# Install Docker
install_docker() {
    log_step "Instalando Docker..."
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable
    systemctl start docker
    systemctl enable docker
    
    # Add user to group
    usermod -aG docker "$SERVICE_USER"
    
    log_info "✓ Docker instalado"
}

# Install Docker Compose
install_docker_compose() {
    log_step "Instalando Docker Compose..."
    
    # Remove old
    rm -f /usr/local/bin/docker-compose
    
    # Install latest
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    log_info "✓ Docker Compose instalado"
}

# Install Firefox and tools
install_firefox() {
    log_step "Instalando Firefox e ferramentas..."
    
    # Install packages
    apt install -y \
        firefox \
        xdotool \
        python3-requests \
        notify-send \
        xvfb \
        x11-utils \
        x11-xserver-utils
    
    log_info "✓ Firefox e dependências instaladas"
}

# Create directories
create_directories() {
    log_step "Criando diretórios..."
    
    mkdir -p "$DATA_DIR"
    mkdir -p "$MEDIA_DIR/images"
    mkdir -p "$MEDIA_DIR/videos"
    mkdir -p "$BACKUP_DIR"
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
    
    log_info "✓ Diretórios criados"
}

# Create initial data
create_initial_data() {
    log_step "Criando dados iniciais..."
    
    # Create empty files
    cat > "$DATA_DIR/tabs.json" << 'EOF'
[]
EOF
    
    # Create admin user (password: admin123)
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
    
    cat > "$DATA_DIR/logs.json" << 'EOF'
[]
EOF
    
    # Set permissions
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"/*.json
    
    log_info "✓ Dados iniciais criados"
}

# Build Docker image (NO CACHE)
build_docker_image() {
    log_step "Construindo imagem Docker (SEM CACHE)..."
    
    cd "$PROJECT_DIR"
    
    # Remove old image
    docker rmi -f credivision-app 2>/dev/null || true
    
    # Clean cache completely
    docker builder prune -a -f
    docker system prune -f
    
    log_info "Construindo imagem (pode demorar 5-10 minutos)..."
    
    # Build without any cache
    if docker build --no-cache --pull -f Dockerfile.production -t credivision-app .; then
        log_info "✓ Imagem Docker construída com sucesso"
    else
        log_error "✗ Falha ao construir imagem Docker"
        exit 1
    fi
}

# Create systemd services
create_services() {
    log_step "Criando serviços systemd..."
    
    # App service
    cat > /etc/systemd/system/credivision-app.service << EOF
[Unit]
Description=CrediVision Flask Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Environment=DATA_FOLDER=$DATA_DIR
Environment=MEDIA_FOLDER=$MEDIA_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Simple kiosk service
    cat > /etc/systemd/system/credivision-kiosk.service << EOF
[Unit]
Description=CrediVision Simple Kiosk
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStartPre=/bin/sleep $KIOSK_DELAY
ExecStart=$PROJECT_DIR/simple_kiosk.sh fullscreen
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Backup service
    cat > /etc/systemd/system/credivision-backup.service << EOF
[Unit]
Description=CrediVision Backup Service

[Service]
Type=oneshot
User=$SERVICE_USER
ExecStart=$PROJECT_DIR/manage_simple_kiosk.sh backup

[Install]
WantedBy=multi-user.target
EOF
    
    # Backup timer
    cat > /etc/systemd/system/credivision-backup.timer << EOF
[Unit]
Description=Run CrediVision backup daily
Requires=credivision-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload and enable
    systemctl daemon-reload
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl enable credivision-backup.timer
    
    log_info "✓ Serviços criados e habilitados"
}

# Setup permissions
setup_permissions() {
    log_step "Configurando permissões..."
    
    # Project permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
    chmod +x "$PROJECT_DIR"/*.sh
    
    # X11 permissions
    usermod -a -G input "$SERVICE_USER"
    usermod -a -G video "$SERVICE_USER"
    
    log_info "✓ Permissões configuradas"
}

# Configure firewall
configure_firewall() {
    log_step "Configurando firewall..."
    
    # Install UFW
    apt install -y ufw
    
    # Configure
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow $APP_PORT/tcp
    
    # Enable
    ufw --force enable
    
    log_info "✓ Firewall configurado"
}

# Test installation
test_installation() {
    log_step "Testando instalação..."
    
    # Start app service
    systemctl start credivision-app.service
    sleep 15
    
    # Test API
    if curl -s "http://localhost:$APP_PORT/api/config" > /dev/null; then
        log_info "✓ API respondendo"
    else
        log_error "✗ API não respondendo"
        return 1
    fi
    
    # Test container
    if docker ps | grep -q "credivision-app"; then
        log_info "✓ Container Docker rodando"
    else
        log_error "✗ Container Docker não rodando"
        return 1
    fi
    
    log_info "✓ Instalação testada com sucesso"
}

# Display final info
display_final_info() {
    log_header "INSTALAÇÃO CONCLUÍDA!"
    echo ""
    echo -e "${GREEN}Informações do Sistema:${NC}"
    echo "  • URL da Aplicação: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
    echo "  • Login Padrão: admin / admin123"
    echo "  • Diretório de Dados: $DATA_DIR"
    echo "  • Diretório de Mídia: $MEDIA_DIR"
    echo ""
    echo -e "${GREEN}Status dos Serviços:${NC}"
    echo "  • credivision-app: $(systemctl is-active credivision-app.service)"
    echo "  • credivision-kiosk: $(systemctl is-active credivision-kiosk.service)"
    echo "  • credivision-backup: $(systemctl is-enabled credivision-backup.timer)"
    echo ""
    echo -e "${GREEN}Comandos Úteis:${NC}"
    echo "  • Ver status: sudo bash $PROJECT_DIR/manage_simple_kiosk.sh status"
    echo "  • Ver logs: sudo bash $PROJECT_DIR/manage_simple_kiosk.sh logs"
    echo "  • Testar kiosk: sudo bash $PROJECT_DIR/manage_simple_kiosk.sh kiosk-test"
    echo "  • Parar tudo: sudo bash $PROJECT_DIR/force_stop_all.sh"
    echo "  • Reconstruir: sudo bash $PROJECT_DIR/manage_simple_kiosk.sh rebuild"
    echo ""
    echo -e "${GREEN}Próximos Passos:${NC}"
    echo "  1. Reinicie o sistema: sudo reboot"
    echo "  2. Aguarde 2-3 minutos"
    echo "  3. Acesse: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
    echo "  4. Faça login (admin/admin123)"
    echo "  5. ⚠️  TROQUE A SENHA PADRÃO!"
    echo "  6. Adicione seu conteúdo (URLs, imagens, vídeos)"
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Troque a senha do admin imediatamente!${NC}"
    echo ""
    echo -e "${CYAN}Sistema Simple Kiosk:${NC}"
    echo "  • Sem iframe - abre sites em janelas reais"
    echo "  • Rotação automática entre janelas"
    echo "  • Suporte total a qualquer site"
    echo "  • Tela cheia real"
    echo ""
}

# Main installation
main() {
    check_root
    display_banner
    check_requirements
    update_system
    install_docker
    install_docker_compose
    install_firefox
    create_directories
    create_initial_data
    build_docker_image
    create_services
    setup_permissions
    configure_firewall
    test_installation
    display_final_info
}

# Run installation
main "$@"
