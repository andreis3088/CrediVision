#!/bin/bash

# CrediVision Manager - Script Unificado FINAL
# Gerenciamento completo do sistema CrediVision

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="informa"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"

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

# Check if running as root for privileged commands
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este comando requer sudo. Use: sudo bash $0"
        exit 1
    fi
}

# Display main menu
show_main_menu() {
    clear
    log_header "CrediVision Manager - Menu Principal"
    echo ""
    echo -e "${MAGENTA}Sistema de Display Digital Kiosk${NC}"
    echo -e "${MAGENTA}Simple Kiosk - Sem Iframe${NC}"
    echo ""
    echo "Selecione uma opção:"
    echo ""
    echo "  ${GREEN}1${NC}) Instalar do Zero"
    echo "  ${GREEN}2${NC}) Atualizar Sistema"
    echo "  ${GREEN}3${NC}) Remover Sistema"
    echo "  ${GREEN}4${NC}) Gerenciar Serviços"
    echo "  ${GREEN}5${NC}) Testar Sistema"
    echo "  ${GREEN}6${NC}) Backup e Restore"
    echo "  ${GREEN}7${NC}) Diagnóstico"
    echo "  ${GREEN}8${NC) Informações do Sistema"
    echo "  ${GREEN}9${NC) Sair"
    echo ""
    read -p "Digite sua opção [1-9]: " choice
    echo ""
    
    case $choice in
        1) install_from_zero ;;
        2) update_system ;;
        3) remove_system ;;
        4) manage_services_menu ;;
        5) test_system_menu ;;
        6) backup_restore_menu ;;
        7) run_diagnosis ;;
        8) show_system_info ;;
        9) exit 0 ;;
        *) log_error "Opção inválida!"; sleep 2; show_main_menu ;;
    esac
}

# Install from zero
install_from_zero() {
    log_header "Instalação do Zero"
    echo ""
    echo -e "${YELLOW}ATENCAO: Isso ira instalar o CrediVision do zero${NC}"
    echo "Este processo ira:"
    echo "  • Instalar Docker e Docker Compose"
    echo "  • Instalar Firefox e dependências"
    echo "  • Configurar servicos systemd"
    echo "  • Criar estrutura de diretorios"
    echo "  • Construir imagem Docker (sem cache)"
    echo ""
    read -p "Deseja continuar? (S/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Cancelado."
        show_main_menu
        return
    fi
    
    check_root
    
    # Step 1: System requirements
    log_step "Verificando requisitos do sistema..."
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script e para Ubuntu"
        exit 1
    fi
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        log_error "Usuario $SERVICE_USER nao existe"
        exit 1
    fi
    
    log_info "✓ Requisitos verificados"
    
    # Step 2: Update system
    log_step "Atualizando sistema..."
    apt update
    apt upgrade -y
    log_info "✓ Sistema atualizado"
    
    # Step 3: Install Docker
    log_step "Instalando Docker..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    
    systemctl start docker
    systemctl enable docker
    usermod -aG docker "$SERVICE_USER"
    
    log_info "✓ Docker instalado"
    
    # Step 4: Install Docker Compose
    log_step "Instalando Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log_info "✓ Docker Compose instalado"
    
    # Step 5: Install Firefox and dependencies
    log_step "Instalando Firefox e dependencias..."
    apt install -y firefox xdotool python3-requests python3-watchdog notify-send xvfb x11-utils
    log_info "✓ Firefox e dependencias instaladas"
    
    # Step 6: Create directories
    log_step "Criando diretorios..."
    mkdir -p "$DATA_DIR"
    mkdir -p "$MEDIA_DIR/images"
    mkdir -p "$MEDIA_DIR/videos"
    mkdir -p "$BACKUP_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
    log_info "✓ Diretorios criados"
    
    # Step 7: Create initial data
    log_step "Criando dados iniciais..."
    cat > "$DATA_DIR/tabs.json" << 'EOF'
[]
EOF
    
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
    
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"/*.json
    log_info "✓ Dados iniciais criados"
    
    # Step 8: Build Docker image
    log_step "Construindo imagem Docker (SEM CACHE)..."
    cd "$PROJECT_DIR"
    docker rmi -f credivision-app 2>/dev/null || true
    docker builder prune -a -f
    docker system prune -f
    
    log_info "Construindo imagem (pode demorar 5-10 minutos)..."
    if docker build --no-cache --pull -f Dockerfile.production -t credivision-app .; then
        log_info "✓ Imagem Docker construida"
    else
        log_error "✗ Falha ao construir imagem"
        exit 1
    fi
    
    # Step 9: Create services
    create_systemd_services
    
    # Step 10: Setup permissions and firewall
    log_step "Configurando permissoes e firewall..."
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
    chmod +x "$PROJECT_DIR"/*.sh
    usermod -a -G input "$SERVICE_USER"
    usermod -a -G video "$SERVICE_USER"
    
    apt install -y ufw
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 5000/tcp
    ufw --force enable
    
    log_info "✓ Permissoes e firewall configurados"
    
    # Step 11: Test installation
    log_step "Testando instalacao..."
    systemctl start credivision-app.service
    sleep 10
    
    if curl -s http://localhost:5000/api/config > /dev/null; then
        log_info "✓ API respondendo"
    else
        log_error "✗ API nao respondendo"
        exit 1
    fi
    
    log_info "✓ Instalacao concluida com sucesso!"
    
    show_installation_info
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Create systemd services
create_systemd_services() {
    log_step "Criando servicos systemd..."
    
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
    
    # Kiosk service
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
ExecStartPre=/bin/sleep 30
ExecStart=$PROJECT_DIR/simple_kiosk_enhanced.sh fullscreen
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Auto-update service
    cat > /etc/systemd/system/credivision-auto-update.service << EOF
[Unit]
Description=CrediVision Auto Update Service
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/usr/bin/python3 $PROJECT_DIR/auto_update_kiosk.py
Restart=always
RestartSec=10

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
ExecStart=$PROJECT_DIR/crevision_manager_new.sh backup-silent

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
    
    systemctl daemon-reload
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl enable credivision-auto-update.service
    systemctl enable credivision-backup.timer
    
    log_info "✓ Servicos criados e habilitados"
}

# Update system
update_system() {
    log_header "Atualizar Sistema"
    echo ""
    echo "Esta opcao ira:"
    echo "  • Atualizar pacotes do sistema"
    echo "  • Reconstruir imagem Docker (sem cache)"
    echo "  • Reiniciar servicos"
    echo ""
    read -p "Deseja continuar? (S/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Cancelado."
        show_main_menu
        return
    fi
    
    check_root
    
    log_step "Atualizando sistema..."
    apt update
    apt upgrade -y
    
    log_step "Reconstruindo imagem Docker..."
    cd "$PROJECT_DIR"
    docker rmi -f credivision-app 2>/dev/null || true
    docker builder prune -a -f
    
    if docker build --no-cache --pull -f Dockerfile.production -t credivision-app .; then
        log_info "✓ Imagem reconstruida"
    else
        log_error "✗ Falha ao reconstruir imagem"
        exit 1
    fi
    
    log_step "Reiniciando servicos..."
    systemctl restart credivision-app.service
    sleep 10
    systemctl restart credivision-auto-update.service
    systemctl restart credivision-kiosk.service
    
    log_info "✓ Sistema atualizado com sucesso!"
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Remove system
remove_system() {
    log_header "Remover Sistema"
    echo ""
    echo -e "${RED}ATENCAO: Isso ira remover completamente o CrediVision${NC}"
    echo "Esta acao ira:"
    echo "  • Parar e remover todos os servicos"
    echo "  • Remover containers e imagens Docker"
    echo "  • Remover arquivos de configuracao"
    echo "  • Fazer backup dos dados antes de remover"
    echo ""
    read -p "Tem certeza que deseja continuar? (SIM): " confirm
    
    if [ "$confirm" != "SIM" ]; then
        log_info "Cancelado."
        show_main_menu
        return
    fi
    
    check_root
    
    # Create backup before removing
    if [ -d "$DATA_DIR" ]; then
        log_step "Fazendo backup dos dados..."
        BACKUP_FILE="$BACKUP_DIR/uninstall_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
        log_info "✓ Backup criado: $BACKUP_FILE"
    fi
    
    # Stop services
    log_step "Parando servicos..."
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    systemctl stop credivision-auto-update.service 2>/dev/null || true
    systemctl stop credivision-app.service 2>/dev/null || true
    systemctl stop credivision-backup.service 2>/dev/null || true
    systemctl stop credivision-backup.timer 2>/dev/null || true
    
    # Disable services
    systemctl disable credivision-kiosk.service 2>/dev/null || true
    systemctl disable credivision-auto-update.service 2>/dev/null || true
    systemctl disable credivision-app.service 2>/dev/null || true
    systemctl disable credivision-backup.service 2>/dev/null || true
    systemctl disable credivision-backup.timer 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/credivision-*.service
    rm -f /etc/systemd/system/credivision-*.timer
    systemctl daemon-reload
    
    # Kill processes
    pkill -f simple_kiosk 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    pkill -f auto_update_kiosk 2>/dev/null || true
    
    # Remove Docker containers and images
    log_step "Removendo containers e imagens Docker..."
    cd "$PROJECT_DIR" 2>/dev/null || cd /tmp
    docker-compose -f docker-compose.production.yml down --remove-orphans 2>/dev/null || true
    docker stop $(docker ps -q) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    docker rmi -f credivision-app 2>/dev/null || true
    docker system prune -a -f
    
    log_info "✓ Sistema removido completamente"
    log_info "Backup dos dados salvo em: $BACKUP_DIR"
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Services management menu
manage_services_menu() {
    while true; do
        clear
        log_header "Gerenciar Servicos"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  ${GREEN}1${NC}) Status de Todos os Servicos"
        echo "  ${GREEN}2${NC}) Iniciar Todos os Servicos"
        echo "  ${GREEN}3${NC}) Parar Todos os Servicos"
        echo "  ${GREEN}4${NC}) Reiniciar Todos os Servicos"
        echo "  ${GREEN}5${NC}) Ver Logs da Aplicacao"
        echo "  ${GREEN}6${NC}) Ver Logs do Kiosk"
        echo "  ${GREEN}7${NC}) Ver Logs do Auto-Update"
        echo "  ${GREEN}8${NC) Menu Principal"
        echo ""
        read -p "Digite sua opcao [1-8]: " choice
        echo ""
        
        case $choice in
            1) show_services_status ;;
            2) start_all_services ;;
            3) stop_all_services ;;
            4) restart_all_services ;;
            5) show_app_logs ;;
            6) show_kiosk_logs ;;
            7) show_auto_update_logs ;;
            8) break ;;
            *) log_error "Opcao invalida!"; sleep 2 ;;
        esac
        
        if [ "$choice" != "8" ]; then
            read -p "Pressione Enter para continuar..."
        fi
    done
    
    show_main_menu
}

# Show services status
show_services_status() {
    log_info "Status dos Servicos:"
    echo ""
    
    for service in credivision-app credivision-kiosk credivision-auto-update credivision-backup; do
        status=$(systemctl is-active "$service.service" 2>/dev/null || echo "not-found")
        enabled=$(systemctl is-enabled "$service.service" 2>/dev/null || echo "not-found")
        echo "$service.service: $status (enabled: $enabled)"
    done
    
    echo ""
    echo "Docker Container:"
    if docker ps | grep -q credivision-app; then
        echo "✓ Container rodando"
        docker ps | grep credivision-app
    else
        echo "✗ Container nao rodando"
    fi
    
    echo ""
    echo "API Test:"
    if curl -s http://localhost:5000/api/config > /dev/null; then
        echo "✓ API respondendo"
    else
        echo "✗ API nao respondendo"
    fi
}

# Start all services
start_all_services() {
    check_root
    log_info "Iniciando todos os servicos..."
    
    systemctl start credivision-app.service
    sleep 10
    systemctl start credivision-auto-update.service
    systemctl start credivision-kiosk.service
    
    log_info "✓ Servicos iniciados"
}

# Stop all services
stop_all_services() {
    check_root
    log_info "Parando todos os servicos..."
    
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-auto-update.service
    systemctl stop credivision-app.service
    
    pkill -f simple_kiosk 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    
    log_info "✓ Servicos parados"
}

# Restart all services
restart_all_services() {
    check_root
    log_info "Reiniciando todos os servicos..."
    
    stop_all_services
    sleep 3
    start_all_services
    
    log_info "✓ Servicos reiniciados"
}

# Show application logs
show_app_logs() {
    echo "Logs da Aplicacao (ultimas 50 linhas):"
    echo "========================================="
    docker logs credivision-app 2>/dev/null | tail -50 || echo "Nenhum log disponivel"
}

# Show kiosk logs
show_kiosk_logs() {
    echo "Logs do Kiosk (ultimas 50 linhas):"
    echo "===================================="
    journalctl -u credivision-kiosk.service -n 50 --no-pager
}

# Show auto-update logs
show_auto_update_logs() {
    echo "Logs do Auto-Update (ultimas 50 linhas):"
    echo "=========================================="
    journalctl -u credivision-auto-update.service -n 50 --no-pager
    echo ""
    echo "Application Log:"
    tail -20 /tmp/credivision_auto_update.log 2>/dev/null || echo "Nenhum log de aplicacao"
}

# Test system menu
test_system_menu() {
    while true; do
        clear
        log_header "Testar Sistema"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  ${GREEN}1${NC}) Testar API"
        echo "  ${GREEN}2${NC}) Testar Kiosk (Modo Debug)"
        echo "  ${GREEN}3${NC}) Testar Auto-Update"
        echo "  ${GREEN}4${NC}) Testar Midia (Imagens/Videos)"
        echo "  ${GREEN}5${NC) Menu Principal"
        echo ""
        read -p "Digite sua opcao [1-5]: " choice
        echo ""
        
        case $choice in
            1) test_api ;;
            2) test_kiosk ;;
            3) test_auto_update ;;
            4) test_media ;;
            5) break ;;
            *) log_error "Opcao invalida!"; sleep 2 ;;
        esac
        
        if [ "$choice" != "5" ]; then
            read -p "Pressione Enter para continuar..."
        fi
    done
    
    show_main_menu
}

# Test API
test_api() {
    log_info "Testando API..."
    
    if curl -s http://localhost:5000/api/config > /dev/null; then
        log_info "✓ API respondendo"
        response=$(curl -s http://localhost:5000/api/config)
        active_tabs=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('tabs', [])))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
        echo "Abas ativas: $active_tabs"
    else
        log_error "✗ API nao respondendo"
    fi
}

# Test kiosk
test_kiosk() {
    log_info "Testando kiosk em modo debug..."
    log_info "Isso abrira o kiosk em janelas separadas para teste"
    log_info "Pressione Ctrl+C para parar"
    echo ""
    
    # Stop existing kiosk
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    pkill -f simple_kiosk 2>/dev/null || true
    
    # Start in debug mode
    if [ -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
        sudo -u "$SERVICE_USER" "$PROJECT_DIR/simple_kiosk_enhanced.sh" debug &
        log_info "Kiosk iniciado em modo debug"
    else
        log_error "Script do kiosk nao encontrado"
    fi
}

# Test auto-update
test_auto_update() {
    log_info "Testando sistema de auto-update..."
    
    if [ -f "$PROJECT_DIR/auto_update_kiosk.py" ]; then
        sudo -u "$SERVICE_USER" python3 "$PROJECT_DIR/auto_update_kiosk.py" --test
    else
        log_error "Script de auto-update nao encontrado"
    fi
}

# Test media
test_media() {
    log_info "Testando suporte a midia..."
    
    if [ -f "$PROJECT_DIR/test_media.sh" ]; then
        sudo -u "$SERVICE_USER" bash "$PROJECT_DIR/test_media.sh"
    else
        log_error "Script de teste de midia nao encontrado"
    fi
}

# Backup and restore menu
backup_restore_menu() {
    while true; do
        clear
        log_header "Backup e Restore"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  ${GREEN}1${NC}) Criar Backup"
        echo "  ${GREEN}2${NC}) Listar Backups"
        echo "  ${GREEN}3${NC}) Restaurar Backup"
        echo "  ${GREEN}4${NC) Menu Principal"
        echo ""
        read -p "Digite sua opcao [1-4]: " choice
        echo ""
        
        case $choice in
            1) create_backup ;;
            2) list_backups ;;
            3) restore_backup ;;
            4) break ;;
            *) log_error "Opcao invalida!"; sleep 2 ;;
        esac
        
        if [ "$choice" != "4" ]; then
            read -p "Pressione Enter para continuar..."
        fi
    done
    
    show_main_menu
}

# Create backup
create_backup() {
    check_root
    log_info "Criando backup..."
    
    BACKUP_FILE="$BACKUP_DIR/manual_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
    chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_FILE"
    
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "✓ Backup criado: $BACKUP_FILE"
    echo "Tamanho: $SIZE"
}

# List backups
list_backups() {
    echo "Backups disponiveis:"
    echo "==================="
    
    if [ -d "$BACKUP_DIR" ]; then
        ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "Nenhum backup encontrado"
    else
        echo "Diretorio de backup nao encontrado"
    fi
}

# Restore backup
restore_backup() {
    check_root
    list_backups
    
    echo ""
    read -p "Digite o nome do arquivo para restaurar: " backup_file
    
    if [ ! -f "$backup_file" ]; then
        log_error "Arquivo nao encontrado: $backup_file"
        return
    fi
    
    log_info "Restaurando backup: $backup_file"
    
    # Create current backup first
    create_backup
    
    # Stop services
    stop_all_services
    
    # Restore
    tar -xzf "$backup_file" -C "/home/$SERVICE_USER/Documents/"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    
    # Start services
    start_all_services
    
    log_info "✓ Backup restaurado com sucesso"
}

# Silent backup (for systemd service)
backup_silent() {
    BACKUP_FILE="$BACKUP_DIR/auto_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
    chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_FILE"
    
    # Keep only last 7 backups
    find "$BACKUP_DIR" -name "auto_backup_*.tar.gz" -mtime +7 -delete
}

# Run diagnosis
run_diagnosis() {
    log_header "Diagnostico do Sistema"
    echo ""
    
    echo "=== Informacoes do Sistema ==="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Usuario: $SERVICE_USER"
    echo ""
    
    echo "=== Status dos Servicos ==="
    for service in credivision-app credivision-kiosk credivision-auto-update credivision-backup; do
        status=$(systemctl is-active "$service.service" 2>/dev/null || echo "not-found")
        echo "$service.service: $status"
    done
    echo ""
    
    echo "=== Docker ==="
    if command -v docker &> /dev/null; then
        echo "✓ Docker instalado: $(docker --version)"
        echo "Status: $(systemctl is-active docker)"
        echo "Containers:"
        docker ps -a
    else
        echo "✗ Docker nao instalado"
    fi
    echo ""
    
    echo "=== Rede ==="
    echo "IP: $(hostname -I | awk '{print $1}')"
    echo "Porta 5000:"
    if netstat -tlnp | grep -q ":5000"; then
        echo "✓ Porta 5000 escutando"
    else
        echo "✗ Porta 5000 nao escutando"
    fi
    echo ""
    
    echo "=== Espaco em Disco ==="
    df -h | grep -E "(Filesystem|/dev/)"
    echo ""
    echo "Diretorios CrediVision:"
    for dir in kiosk-data kiosk-media kiosk-backups; do
        path="/home/$SERVICE_USER/Documents/$dir"
        if [ -d "$path" ]; then
            size=$(du -sh "$path" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        else
            echo "  $dir: nao encontrado"
        fi
    done
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Show system info
show_system_info() {
    log_header "Informacoes do Sistema"
    echo ""
    
    echo "=== CrediVision - Simple Kiosk ==="
    echo ""
    echo "URL da Aplicacao: http://$(hostname -I | awk '{print $1}'):5000"
    echo "Login Padrao: admin / admin123"
    echo ""
    echo "Diretorios:"
    echo "  Dados: $DATA_DIR"
    echo "  Midia: $MEDIA_DIR"
    echo "  Backups: $BACKUP_DIR"
    echo "  Projeto: $PROJECT_DIR"
    echo ""
    echo "Caracteristicas:"
    echo "  ✓ Simple Kiosk (sem iframe)"
    echo "  ✓ Suporte a imagens, videos e URLs"
    echo "  ✓ Atualizacao automatica"
    echo "  ✓ Rotacao automatica de conteudo"
    echo "  ✓ Tela cheia real"
    echo ""
    echo "Comandos Uteis:"
    echo "  Status: sudo bash $0"
    echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo "  Teste: sudo bash $0 (opcao 5)"
    echo ""
    echo "Como funciona:"
    echo "  1. Adicione conteudo na interface web"
    echo "  2. Sistema atualiza automaticamente"
    echo "  3. Kiosk exibe em tela cheia"
    echo "  4. Rotacao automatica entre itens"
    echo ""
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Show installation info
show_installation_info() {
    echo ""
    log_header "INSTALACAO CONCLUIDA!"
    echo ""
    echo -e "${GREEN}Informacoes do Sistema:${NC}"
    echo "  • URL: http://$(hostname -I | awk '{print $1}'):5000"
    echo "  • Login: admin / admin123"
    echo "  • Dados: $DATA_DIR"
    echo "  • Midia: $MEDIA_DIR"
    echo ""
    echo -e "${GREEN}Proximos Passos:${NC}"
    echo "  1. Reinicie o sistema: sudo reboot"
    echo "  2. Aguarde 2-3 minutos"
    echo "  3. Acesse a interface web"
    echo "  4. TROQUE A SENHA PADRAO!"
    echo "  5. Adicione seu conteudo"
    echo ""
    echo -e "${GREEN}Comandos Uteis:${NC}"
    echo "  • Gerenciar: sudo bash $0"
    echo "  • Status: sudo bash $0 (opcao 4.1)"
    echo "  • Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Troque a senha do admin imediatamente!${NC}"
    echo ""
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Check if script is being called with specific function
    if [ "$1" = "backup-silent" ]; then
        backup_silent
        exit 0
    fi
    
    # Show main menu
    show_main_menu
fi
