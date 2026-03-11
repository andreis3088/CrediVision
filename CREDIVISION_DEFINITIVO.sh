#!/bin/bash

# CREDIVISION DEFINITIVO - Sistema Completo de Display Digital
# Simple Kiosk com Firefox - Sem Iframe
# Gerenciamento completo via interface web

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuracao
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="informa"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"

# Funcoes de log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

# Verificar root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este comando requer sudo. Use: sudo bash $0"
        exit 1
    fi
}

# Menu principal
show_main_menu() {
    clear
    log_header "CREDIVISION - Display Digital"
    echo ""
    echo "Simple Kiosk - Firefox Sem Iframe"
    echo "Gerenciamento via Interface Web"
    echo ""
    echo "Selecione uma opcao:"
    echo ""
    echo "  1) Instalar Sistema Completo"
    echo "  2) Atualizar Sistema"
    echo "  3) Remover Sistema"
    echo "  4) Gerenciar Servicos"
    echo "  5) Testar Sistema"
    echo "  6) Backup e Restore"
    echo "  7) Diagnostico"
    echo "  8) Informacoes"
    echo "  9) Sair"
    echo ""
    read -p "Digite sua opcao [1-9]: " choice
    echo ""
    
    case $choice in
        1) install_system ;;
        2) update_system ;;
        3) remove_system ;;
        4) manage_services ;;
        5) test_system ;;
        6) backup_restore ;;
        7) run_diagnosis ;;
        8) show_info ;;
        9) exit 0 ;;
        *) log_error "Opcao invalida!"; sleep 2; show_main_menu ;;
    esac
}

# Instalacao completa
install_system() {
    log_header "INSTALACAO COMPLETA"
    echo ""
    echo "Este processo ira:"
    echo "  • Instalar Docker e Docker Compose"
    echo "  • Instalar Firefox e dependencias"
    echo "  • Configurar ambiente X11"
    echo "  • Criar estrutura de diretorios"
    echo "  • Construir imagem Docker"
    echo "  • Configurar servicos systemd"
    echo "  • Configurar firewall"
    echo ""
    read -p "Deseja continuar? (S/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Cancelado."
        show_main_menu
        return
    fi
    
    check_root
    
    # Passo 1: Verificar sistema
    log_step "Verificando sistema..."
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Este script e para Ubuntu"
        exit 1
    fi
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        log_error "Usuario $SERVICE_USER nao existe"
        exit 1
    fi
    
    log_info "Sistema OK"
    
    # Passo 2: Atualizar sistema
    log_step "Atualizando sistema..."
    apt update
    apt upgrade -y
    
    # Passo 3: Instalar Docker
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
    
    log_info "Docker instalado"
    
    # Passo 4: Docker Compose
    log_step "Instalando Docker Compose..."
    rm -f /usr/local/bin/docker-compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log_info "Docker Compose instalado"
    
    # Passo 5: Firefox e dependencias
    log_step "Instalando Firefox e dependencias..."
    apt install -y firefox xdotool python3 python3-pip python3-requests python3-watchdog libnotify-bin xvfb x11-utils
    
    # Instalar watchdog
    pip3 install watchdog
    
    log_info "Firefox e dependencias instaladas"
    
    # Passo 6: Configurar ambiente X11
    log_step "Configurando ambiente X11..."
    
    # Adicionar usuario aos grupos
    usermod -a -G audio,video,input,plugdev,render "$SERVICE_USER"
    
    # Configurar X11
    if [ ! -f "/etc/X11/Xwrapper.config" ]; then
        echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
    fi
    
    # Configurar DISPLAY
    cat >> /home/$SERVICE_USER/.bashrc << 'EOF'

# Configuracoes X11 para CrediVision
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority
EOF
    
    log_info "Ambiente X11 configurado"
    
    # Passo 7: Criar diretorios
    log_step "Criando estrutura de diretorios..."
    mkdir -p "$DATA_DIR"
    mkdir -p "$MEDIA_DIR/images"
    mkdir -p "$MEDIA_DIR/videos"
    mkdir -p "$BACKUP_DIR"
    
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
    
    log_info "Diretorios criados"
    
    # Passo 8: Criar dados iniciais
    log_step "Criando dados iniciais..."
    
    # Senha padrao: admin123 (hash: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)
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
    
    cat > "$DATA_DIR/tabs.json" << 'EOF'
[]
EOF
    
    cat > "$DATA_DIR/logs.json" << 'EOF'
[]
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"/*.json
    
    log_info "Dados iniciais criados"
    
    # Passo 9: Construir imagem Docker
    log_step "Construindo imagem Docker..."
    cd "$PROJECT_DIR"
    
    # Limpar imagens antigas
    docker rmi -f credivision-app 2>/dev/null || true
    docker builder prune -a -f
    docker system prune -f
    
    log_info "Construindo imagem (pode demorar 5-10 minutos)..."
    if docker build --no-cache --pull -f Dockerfile.production -t credivision-app .; then
        log_info "Imagem Docker construida"
    else
        log_error "Falha ao construir imagem Docker"
        exit 1
    fi
    
    # Passo 10: Criar servicos systemd
    create_systemd_services
    
    # Passo 11: Configurar firewall
    log_step "Configurando firewall..."
    
    # Configurar permissoes dos scripts
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
    chmod +x "$PROJECT_DIR"/*.sh
    
    # Configurar UFW
    apt install -y ufw
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 5000/tcp
    ufw --force enable
    
    log_info "Firewall configurado"
    
    # Passo 12: Testar instalacao
    log_step "Testando instalacao..."
    
    systemctl start credivision-app.service
    sleep 15
    
    if curl -s http://localhost:5000/api/config > /dev/null; then
        log_info "API respondendo - OK"
    else
        log_error "API nao respondendo"
        echo "Verificando logs:"
        docker logs credivision-app 2>/dev/null | tail -20
        exit 1
    fi
    
    log_info "Instalacao concluida com sucesso!"
    
    show_installation_info
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Criar servicos systemd
create_systemd_services() {
    log_step "Criando servicos systemd..."
    
    # Servico da aplicacao
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
    
    # Servico do kiosk
    cat > /etc/systemd/system/credivision-kiosk.service << EOF
[Unit]
Description=CrediVision Firefox Kiosk
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
    
    # Servico de auto-update
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
    
    # Servico de backup
    cat > /etc/systemd/system/credivision-backup.service << EOF
[Unit]
Description=CrediVision Backup Service

[Service]
Type=oneshot
User=$SERVICE_USER
ExecStart=$PROJECT_DIR/CREDIVISION_DEFINITIVO.sh backup-silent

[Install]
WantedBy=multi-user.target
EOF
    
    # Timer de backup
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
    
    # Reload e habilitar servicos
    systemctl daemon-reload
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl enable credivision-auto-update.service
    systemctl enable credivision-backup.timer
    
    log_info "Servicos criados e habilitados"
}

# Atualizar sistema
update_system() {
    log_header "ATUALIZAR SISTEMA"
    echo ""
    echo "Esta opcao ira:"
    echo "  • Atualizar pacotes do sistema"
    echo "  • Reconstruir imagem Docker"
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
        log_info "Imagem reconstruida"
    else
        log_error "Falha ao reconstruir imagem"
        exit 1
    fi
    
    log_step "Reiniciando servicos..."
    systemctl restart credivision-app.service
    sleep 10
    systemctl restart credivision-auto-update.service
    systemctl restart credivision-kiosk.service
    
    log_info "Sistema atualizado"
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Remover sistema
remove_system() {
    log_header "REMOVER SISTEMA"
    echo ""
    echo "ATENCAO: Isso ira remover completamente o CrediVision"
    echo ""
    read -p "Tem certeza? Digite SIM para confirmar: " confirm
    
    if [ "$confirm" != "SIM" ]; then
        log_info "Cancelado."
        show_main_menu
        return
    fi
    
    check_root
    
    # Backup antes de remover
    if [ -d "$DATA_DIR" ]; then
        log_step "Fazendo backup..."
        BACKUP_FILE="$BACKUP_DIR/uninstall_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
        log_info "Backup criado: $BACKUP_FILE"
    fi
    
    # Parar servicos
    log_step "Parando servicos..."
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    systemctl stop credivision-auto-update.service 2>/dev/null || true
    systemctl stop credivision-app.service 2>/dev/null || true
    systemctl stop credivision-backup.service 2>/dev/null || true
    systemctl stop credivision-backup.timer 2>/dev/null || true
    
    # Desabilitar servicos
    systemctl disable credivision-kiosk.service 2>/dev/null || true
    systemctl disable credivision-auto-update.service 2>/dev/null || true
    systemctl disable credivision-app.service 2>/dev/null || true
    systemctl disable credivision-backup.service 2>/dev/null || true
    systemctl disable credivision-backup.timer 2>/dev/null || true
    
    # Remover arquivos de servico
    rm -f /etc/systemd/system/credivision-*.service
    rm -f /etc/systemd/system/credivision-*.timer
    systemctl daemon-reload
    
    # Matar processos
    pkill -f simple_kiosk 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    pkill -f auto_update_kiosk 2>/dev/null || true
    
    # Remover Docker
    log_step "Removendo containers e imagens..."
    cd "$PROJECT_DIR" 2>/dev/null || cd /tmp
    docker-compose -f docker-compose.production.yml down --remove-orphans 2>/dev/null || true
    docker stop $(docker ps -q) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    docker rmi -f credivision-app 2>/dev/null || true
    docker system prune -a -f
    
    log_info "Sistema removido completamente"
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Gerenciar servicos
manage_services() {
    while true; do
        clear
        log_header "GERENCIAR SERVICOS"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  1) Status dos Servicos"
        echo "  2) Iniciar Todos"
        echo "  3) Parar Todos"
        echo "  4) Reiniciar Todos"
        echo "  5) Logs Aplicacao"
        echo "  6) Logs Kiosk"
        echo "  7) Logs Auto-Update"
        echo "  8) Menu Principal"
        echo ""
        read -p "Opcao [1-8]: " choice
        echo ""
        
        case $choice in
            1) show_status ;;
            2) start_services ;;
            3) stop_services ;;
            4) restart_services ;;
            5) show_app_logs ;;
            6) show_kiosk_logs ;;
            7) show_auto_logs ;;
            8) break ;;
            *) log_error "Opcao invalida!"; sleep 2 ;;
        esac
        
        if [ "$choice" != "8" ]; then
            read -p "Pressione Enter para continuar..."
        fi
    done
    
    show_main_menu
}

# Mostrar status
show_status() {
    log_info "Status dos Servicos:"
    echo ""
    
    for service in credivision-app credivision-kiosk credivision-auto-update credivision-backup; do
        status=$(systemctl is-active "$service.service" 2>/dev/null || echo "not-found")
        enabled=$(systemctl is-enabled "$service.service" 2>/dev/null || echo "not-enabled")
        echo "$service.service: $status (enabled: $enabled)"
    done
    
    echo ""
    echo "Docker:"
    if docker ps | grep -q credivision-app; then
        echo "Container: rodando"
        docker ps | grep credivision-app
    else
        echo "Container: nao rodando"
    fi
    
    echo ""
    echo "API:"
    if curl -s http://localhost:5000/api/config > /dev/null; then
        echo "API: respondendo"
    else
        echo "API: nao respondendo"
    fi
}

# Iniciar servicos
start_services() {
    check_root
    log_info "Iniciando servicos..."
    
    systemctl start credivision-app.service
    sleep 10
    systemctl start credivision-auto-update.service
    systemctl start credivision-kiosk.service
    
    log_info "Servicos iniciados"
}

# Parar servicos
stop_services() {
    check_root
    log_info "Parando servicos..."
    
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-auto-update.service
    systemctl stop credivision-app.service
    
    pkill -f simple_kiosk 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    
    log_info "Servicos parados"
}

# Reiniciar servicos
restart_services() {
    check_root
    log_info "Reiniciando servicos..."
    
    stop_services
    sleep 3
    start_services
    
    log_info "Servicos reiniciados"
}

# Logs aplicacao
show_app_logs() {
    echo "Logs da Aplicacao (50 linhas):"
    echo "================================="
    docker logs credivision-app 2>/dev/null | tail -50 || echo "Nenhum log"
}

# Logs kiosk
show_kiosk_logs() {
    echo "Logs do Kiosk (50 linhas):"
    echo "============================="
    journalctl -u credivision-kiosk.service -n 50 --no-pager
}

# Logs auto-update
show_auto_logs() {
    echo "Logs do Auto-Update (50 linhas):"
    echo "================================="
    journalctl -u credivision-auto-update.service -n 50 --no-pager
    echo ""
    echo "Application Log:"
    tail -20 /tmp/credivision_auto_update.log 2>/dev/null || echo "Nenhum log"
}

# Testar sistema
test_system() {
    while true; do
        clear
        log_header "TESTAR SISTEMA"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  1) Testar API"
        echo "  2) Testar Kiosk (Debug)"
        echo "  3) Testar Auto-Update"
        echo "  4) Testar Midia"
        echo "  5) Menu Principal"
        echo ""
        read -p "Opcao [1-5]: " choice
        echo ""
        
        case $choice in
            1) test_api ;;
            2) test_kiosk ;;
            3) test_auto ;;
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

# Testar API
test_api() {
    log_info "Testando API..."
    
    if curl -s http://localhost:5000/api/config > /dev/null; then
        log_info "API respondendo"
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
        log_error "API nao respondendo"
    fi
}

# Testar kiosk
test_kiosk() {
    log_info "Testando kiosk em modo debug..."
    log_info "Isso abrira janelas separadas para teste"
    log_info "Pressione Ctrl+C para parar"
    echo ""
    
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    pkill -f simple_kiosk 2>/dev/null || true
    
    if [ -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
        sudo -u "$SERVICE_USER" "$PROJECT_DIR/simple_kiosk_enhanced.sh" debug &
        log_info "Kiosk iniciado em modo debug"
    else
        log_error "Script do kiosk nao encontrado"
    fi
}

# Testar auto-update
test_auto() {
    log_info "Testando auto-update..."
    
    if [ -f "$PROJECT_DIR/auto_update_kiosk.py" ]; then
        sudo -u "$SERVICE_USER" python3 "$PROJECT_DIR/auto_update_kiosk.py" --test
    else
        log_error "Script de auto-update nao encontrado"
    fi
}

# Testar midia
test_media() {
    log_info "Testando suporte a midia..."
    
    if [ -f "$PROJECT_DIR/test_media.sh" ]; then
        sudo -u "$SERVICE_USER" bash "$PROJECT_DIR/test_media.sh"
    else
        log_error "Script de teste de midia nao encontrado"
    fi
}

# Backup e restore
backup_restore() {
    while true; do
        clear
        log_header "BACKUP E RESTORE"
        echo ""
        echo "Selecione uma opcao:"
        echo ""
        echo "  1) Criar Backup"
        echo "  2) Listar Backups"
        echo "  3) Restaurar Backup"
        echo "  4) Menu Principal"
        echo ""
        read -p "Opcao [1-4]: " choice
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

# Criar backup
create_backup() {
    check_root
    log_info "Criando backup..."
    
    BACKUP_FILE="$BACKUP_DIR/manual_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
    chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_FILE"
    
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "Backup criado: $BACKUP_FILE"
    echo "Tamanho: $SIZE"
}

# Listar backups
list_backups() {
    echo "Backups disponiveis:"
    echo "==================="
    
    if [ -d "$BACKUP_DIR" ]; then
        ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "Nenhum backup"
    else
        echo "Diretorio de backup nao encontrado"
    fi
}

# Restaurar backup
restore_backup() {
    check_root
    list_backups
    
    echo ""
    read -p "Nome do arquivo para restaurar: " backup_file
    
    if [ ! -f "$backup_file" ]; then
        log_error "Arquivo nao encontrado: $backup_file"
        return
    fi
    
    log_info "Restaurando backup: $backup_file"
    
    create_backup
    stop_services
    
    tar -xzf "$backup_file" -C "/home/$SERVICE_USER/Documents/"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    
    start_services
    
    log_info "Backup restaurado"
}

# Backup silencioso
backup_silent() {
    BACKUP_FILE="$BACKUP_DIR/auto_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents" kiosk-data kiosk-media
    chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_FILE"
    
    # Manter apenas 7 dias
    find "$BACKUP_DIR" -name "auto_backup_*.tar.gz" -mtime +7 -delete
}

# Diagnostico
run_diagnosis() {
    log_header "DIAGNOSTICO COMPLETO"
    echo ""
    
    echo "=== Sistema ==="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Usuario: $SERVICE_USER"
    echo ""
    
    echo "=== Servicos ==="
    for service in credivision-app credivision-kiosk credivision-auto-update credivision-backup; do
        status=$(systemctl is-active "$service.service" 2>/dev/null || echo "not-found")
        echo "$service.service: $status"
    done
    echo ""
    
    echo "=== Docker ==="
    if command -v docker &> /dev/null; then
        echo "Docker: $(docker --version)"
        echo "Status: $(systemctl is-active docker)"
        docker ps -a
    else
        echo "Docker: nao instalado"
    fi
    echo ""
    
    echo "=== Rede ==="
    echo "IP: $(hostname -I | awk '{print $1}')"
    echo "Porta 5000:"
    if netstat -tlnp | grep -q ":5000"; then
        echo "Porta 5000: escutando"
    else
        echo "Porta 5000: nao escutando"
    fi
    echo ""
    
    echo "=== Disco ==="
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

# Mostrar informacoes
show_info() {
    log_header "INFORMACOES DO SISTEMA"
    echo ""
    
    echo "=== CREDIVISION ==="
    echo "Sistema: Display Digital com Simple Kiosk"
    echo "Navegador: Firefox (sem iframe)"
    echo "Gerenciamento: Interface Web"
    echo ""
    echo "URL: http://$(hostname -I | awk '{print $1}'):5000"
    echo "Login: admin / admin123"
    echo ""
    echo "Diretorios:"
    echo "  Dados: $DATA_DIR"
    echo "  Midia: $MEDIA_DIR"
    echo "  Backups: $BACKUP_DIR"
    echo "  Projeto: $PROJECT_DIR"
    echo ""
    echo "Caracteristicas:"
    echo "  ✓ Firefox Kiosk (sem iframe)"
    echo "  ✓ Suporte a imagens, videos e URLs"
    echo "  ✓ Rotacao automatica"
    echo "  ✓ Tempo configuravel por aba"
    echo "  ✓ Atualizacao automatica"
    echo "  ✓ Tela cheia real"
    echo ""
    echo "Como usar:"
    echo "  1. Acesse a interface web"
    echo "  2. Va em 'Abas'"
    echo "  3. Adicione URLs, imagens ou videos"
    echo "  4. Configure tempo de exibicao"
    echo "  5. Sistema atualiza automaticamente"
    echo ""
    echo "Comandos:"
    echo "  Gerenciar: sudo bash $0"
    echo "  Status: sudo bash $0 (opcao 4.1)"
    echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo ""
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Informacoes de instalacao
show_installation_info() {
    echo ""
    log_header "INSTALACAO CONCLUIDA!"
    echo ""
    echo "Sistema: CREDIVISION - Display Digital"
    echo "URL: http://$(hostname -I | awk '{print $1}'):5000"
    echo "Login: admin / admin123"
    echo ""
    echo "Proximos Passos:"
    echo "  1. REINICIE O SISTEMA: sudo reboot"
    echo "  2. Aguarde 2-3 minutos"
    echo "  3. Acesse a URL acima"
    echo "  4. TROQUE A SENHA PADRAO!"
    echo "  5. Adicione suas abas"
    echo ""
    echo "Tipos de conteudo:"
    echo "  • URL: Sites externos"
    echo "  • Imagem: Arquivos de imagem"
    echo "  • Video: Arquivos de video"
    echo ""
    echo "Configuracoes:"
    echo "  • Tempo: Segundos por aba"
    echo "  • Nome: Identificacao"
    echo "  • Status: Ativar/Desativar"
    echo ""
    echo "IMPORTANTE:"
    echo "  • Troque a senha do admin"
    echo "  • Configure firewall se necessario"
    echo "  • Monitore os logs regularmente"
    echo ""
}

# Execucao principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ "$1" = "backup-silent" ]; then
        backup_silent
        exit 0
    fi
    
    show_main_menu
fi
