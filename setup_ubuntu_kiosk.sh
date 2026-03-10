#!/bin/bash

# Script Completo de Instalação - CrediVision Kiosk Ubuntu
# Uso: sudo bash setup_ubuntu_kiosk.sh

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}$1${NC} ${PURPLE}$(printf "%*s" $((70 - ${#1})) "")${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Banner
clear
print_header "CREDIVISION KIOSK - INSTALAÇÃO COMPLETA UBUNTU"
echo ""
echo -e "${CYAN}Sistema Kiosk Automático com Delay de 30 Segundos${NC}"
echo -e "${CYAN}Persistência Total em ~/Documents/${NC}"
echo ""

# Verificar root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Configurar variáveis
PROJECT_DIR="/opt/credvision"
GIT_REPO="https://github.com/SEU-USUARIO/credvision.git"
DATA_DIR="/home/$SUDO_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SUDO_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SUDO_USER/Documents/kiosk-backups"
SERVICE_USER="$SUDO_USER"

print_step "Configurando variáveis..."
echo "   📁 Projeto: $PROJECT_DIR"
echo "   📁 Dados: $DATA_DIR"
echo "   📁 Mídia: $MEDIA_DIR"
echo "   📁 Backups: $BACKUP_DIR"
echo "   👤 Usuário: $SERVICE_USER"
echo ""

# ETAPA 1: Atualizar Sistema
print_header "ETAPA 1: ATUALIZAÇÃO DO SISTEMA"
print_step "Atualizando sistema..."
apt update && apt upgrade -y

# ETAPA 2: Instalar Dependências
print_header "ETAPA 2: DEPENDÊNCIAS ESSENCIAIS"
print_step "Instalando pacotes básicos..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    nano \
    vim \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    sqlite3 \
    firefox \
    zenity \
    x11-utils \
    x11-xserver-utils

# ETAPA 3: Instalar Docker
print_header "ETAPA 3: INSTALAÇÃO DOCKER"
print_step "Removendo versões antigas..."
apt remove -y docker docker-engine docker.io containerd runc || true

print_step "Adicionando repositório Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

print_step "Instalando Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

print_step "Configurando permissões Docker..."
usermod -aG docker $SUDO_USER || true
systemctl start docker
systemctl enable docker

# ETAPA 4: Clonar Repositório
print_header "ETAPA 4: CLONAR REPOSITÓRIO"
print_step "Clonando repositório CrediVision..."

mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

if [ -d ".git" ]; then
    print_status "Repositório já existe. Atualizando..."
    git pull origin main
else
    print_status "Clonando repositório..."
    git clone $GIT_REPO .
fi

# ETAPA 5: Criar Estrutura de Diretórios
print_header "ETAPA 5: ESTRUTURA DE DIRETÓRIOS"
print_step "Criando diretórios essenciais..."

mkdir -p "$DATA_DIR"
mkdir -p "$MEDIA_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$PROJECT_DIR/logs"

# Criar subdiretórios de mídia
mkdir -p "$MEDIA_DIR/imagens"
mkdir -p "$MEDIA_DIR/videos"
mkdir -p "$MEDIA_DIR/outros"

chown -R $SUDO_USER:$SUDO_USER "$DATA_DIR"
chown -R $SUDO_USER:$SUDO_USER "$MEDIA_DIR"
chown -R $SUDO_USER:$SUDO_USER "$BACKUP_DIR"
chown -R $SUDO_USER:$SUDO_USER "$PROJECT_DIR"

chmod 755 "$DATA_DIR"
chmod 755 "$MEDIA_DIR"
chmod 755 "$BACKUP_DIR"

print_status "Diretórios criados:"
echo "   📁 $PROJECT_DIR - Projeto"
echo "   📁 $DATA_DIR - Dados JSON"
echo "   📁 $MEDIA_DIR - Arquivos de mídia"
echo "   📁 $BACKUP_DIR - Backups automáticos"

# ETAPA 6: Configurar Ambiente Python
print_header "ETAPA 6: CONFIGURAÇÃO PYTHON"
print_step "Criando ambiente virtual..."
cd $PROJECT_DIR
sudo -u $SUDO_USER python3 -m venv venv

print_step "Instalando dependências..."
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"

# ETAPA 7: Criar Docker Compose
print_header "ETAPA 7: CONFIGURAÇÃO DOCKER COMPOSE"
print_step "Criando docker-compose.yml..."

cat > $PROJECT_DIR/docker-compose.yml << EOF
version: "3.9"

services:
  credvision-app:
    build: .
    container_name: credvision-app
    volumes:
      - $DATA_DIR:/data:rw
      - $MEDIA_DIR:/media:rw
    environment:
      - DATA_FOLDER=/data
      - MEDIA_FOLDER=/media
      - ADMIN_URL=http://localhost:5000
      - KIOSK_MODE=app-only
      - CONFIG_REFRESH=300
    ports:
      - "5000:5000"
    restart: unless-stopped
    networks:
      - credvision-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/config"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  credvision-net:
    driver: bridge
EOF

# Criar Dockerfile
print_step "Criando Dockerfile..."
cat > $PROJECT_DIR/Dockerfile << EOF
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements e instalar
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar aplicação
COPY . .

# Criar diretórios
RUN mkdir -p /data /media

# Expor porta
EXPOSE 5000

# Comando de inicialização
CMD ["python", "app_no_db.py"]
EOF

# ETAPA 8: Configurar Variáveis de Ambiente
print_header "ETAPA 8: VARIÁVEIS DE AMBIENTE"
print_step "Criando arquivo .env..."

SECRET_KEY=$(openssl rand -hex 32)

cat > $PROJECT_DIR/.env << EOF
# Configurações do CrediVision Kiosk
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
ADMIN_URL=http://localhost:5000
KIOSK_MODE=app-only
CONFIG_REFRESH=300
DISPLAY=:0

# Configurações de segurança
SESSION_TIMEOUT=3600
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900

# Configurações de upload
MAX_FILE_SIZE=104857600
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,mp4,avi,mov,webm

# Configurações dos arquivos JSON
TABS_FILE=/data/tabs.json
USERS_FILE=/data/users.json
LOGS_FILE=/data/logs.json
EOF

chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/.env
chmod 600 $PROJECT_DIR/.env

# ETAPA 9: Configurar Firewall
print_header "ETAPA 9: CONFIGURAÇÃO DE FIREWALL"
if command -v ufw >/dev/null 2>&1; then
    print_step "Configurando UFW..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 5000/tcp
    ufw --force enable
    print_status "Firewall configurado"
else
    print_warning "UFW não encontrado"
fi

# ETAPA 10: Criar Services Systemd
print_header "ETAPA 10: SERVIÇOS SYSTEMD"

# Serviço principal Docker
print_step "Criando credvision-app.service..."
cat > /etc/systemd/system/credvision-app.service << EOF
[Unit]
Description=CrediVision Docker App
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
TimeoutStartSec=0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Serviço de boot com delay
print_step "Criando credvision-boot.service..."
cat > /etc/systemd/system/credvision-boot.service << EOF
[Unit]
Description=CrediVision Boot Screen
After=graphical-session.target

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/usr/bin/zenity --info --title="CrediVision Kiosk" --text="\\n<b>CrediVision Kiosk</b>\\n\\n🚀 Iniciando sistema...\\n\\n⏱️ Aguarde 30 segundos para o kiosk abrir\\n\\n📺 O conteúdo será exibido automaticamente\\n\\n🔧 Acesso admin: http://$(hostname -I | awk '{print $1}'):5000\\n\\n👤 Login: admin / admin123" --timeout=30 --width=500 --height=300
Restart=no

[Install]
WantedBy=graphical-session.target
EOF

# Serviço Kiosk com delay de 30 segundos
print_step "Criando credvision-kiosk.service..."
cat > /etc/systemd/system/credvision-kiosk.service << EOF
[Unit]
Description=CrediVision Firefox Kiosk Display
After=credvision-app.service
Wants=credvision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/bin/bash -c 'sleep 30 && /usr/bin/firefox --kiosk http://localhost:5000/display --no-first-run --disable-pinch --disable-infobars'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
EOF

# Serviço de backup automático
print_step "Criando credvision-backup.service..."
cat > /etc/systemd/system/credvision-backup.service << EOF
[Unit]
Description=CrediVision Automatic Backup
After=credvision-app.service

[Service]
Type=oneshot
User=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/backup_kiosk.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Timer para backup diário
print_step "Criando credvision-backup.timer..."
cat > /etc/systemd/system/credvision-backup.timer << EOF
[Unit]
Description=Daily CrediVision Backup
Requires=credvision-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Habilitar serviços
print_step "Habilitando serviços..."
systemctl daemon-reload
systemctl enable credvision-app.service
systemctl enable credvision-boot.service
systemctl enable credvision-kiosk.service
systemctl enable credvision-backup.timer

# ETAPA 11: Criar Scripts de Manutenção
print_header "ETAPA 11: SCRIPTS DE MANUTENÇÃO"

# Script de backup
print_step "Criando backup_kiosk.sh..."
cat > $PROJECT_DIR/backup_kiosk.sh << EOF
#!/bin/bash

BACKUP_DIR="$BACKUP_DIR"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/credvision_kiosk_\$DATE.tar.gz"

echo "💾 Criando backup do CrediVision Kiosk..."

# Criar diretório de backup
mkdir -p \$BACKUP_DIR

# Parar kiosk temporariamente
systemctl stop credvision-kiosk || true

# Criar backup
tar -czf \$BACKUP_FILE \\
    $PROJECT_DIR \\
    $DATA_DIR \\
    $MEDIA_DIR \\
    /etc/systemd/system/credvision-*.service \\
    /etc/systemd/system/credvision-*.timer \\
    2>/dev/null || true

# Reiniciar kiosk
systemctl start credvision-kiosk

echo "✅ Backup criado: \$BACKUP_FILE"
echo "📊 Tamanho: \$(du -h \$BACKUP_FILE | cut -f1)"

# Manter apenas os últimos 7 backups
find \$BACKUP_DIR -name "credvision_kiosk_*.tar.gz" -mtime +7 -delete

echo "🗑️ Backups antigos removidos"
EOF

chmod +x $PROJECT_DIR/backup_kiosk.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/backup_kiosk.sh

# Script de diagnóstico
print_step "Criando diagnose_kiosk.sh..."
cat > $PROJECT_DIR/diagnose_kiosk.sh << EOF
#!/bin/bash

echo "🔍 Diagnóstico do CrediVision Kiosk"
echo "=================================="

# Informações do sistema
echo "📊 Sistema:"
echo "   OS: \$(lsb_release -d | cut -f2)"
echo "   Kernel: \$(uname -r)"
echo "   Uptime: \$(uptime -p)"
echo ""

# Status dos serviços
echo "🔧 Serviços:"
systemctl is-active credvision-app && echo "   ✅ CrediVision App: Ativo" || echo "   ❌ CrediVision App: Inativo"
systemctl is-active credvision-kiosk && echo "   ✅ CrediVision Kiosk: Ativo" || echo "   ❌ CrediVision Kiosk: Inativo"
systemctl is-active credvision-backup.timer && echo "   ✅ Backup Timer: Ativo" || echo "   ❌ Backup Timer: Inativo"
echo ""

# Docker
echo "🐳 Docker:"
docker --version 2>/dev/null || echo "   ❌ Docker não instalado"
docker compose version 2>/dev/null || echo "   ❌ Docker Compose não instalado"
echo ""

# Container
echo "📦 Container Docker:"
if docker ps | grep credvision-app >/dev/null 2>&1; then
    echo "   ✅ Container credvision-app: Rodando"
    echo "   📊 Status: \$(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep credvision-app)"
else
    echo "   ❌ Container credvision-app: Parado"
fi
echo ""

# Diretórios
echo "📁 Diretórios:"
[ -d "$PROJECT_DIR" ] && echo "   ✅ Projeto: Existe" || echo "   ❌ Projeto: Não existe"
[ -d "$DATA_DIR" ] && echo "   ✅ Dados: Existe" || echo "   ❌ Dados: Não existe"
[ -d "$MEDIA_DIR" ] && echo "   ✅ Mídia: Existe" || echo "   ❌ Mídia: Não existe"
echo ""

# Arquivos JSON
echo "📋 Arquivos JSON:"
[ -f "$DATA_DIR/tabs.json" ] && echo "   ✅ tabs.json: Existe (\$(cat $DATA_DIR/tabs.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data))") abas)" || echo "   ❌ tabs.json: Não existe"
[ -f "$DATA_DIR/users.json" ] && echo "   ✅ users.json: Existe (\$(cat $DATA_DIR/users.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data))") usuários)" || echo "   ❌ users.json: Não existe"
[ -f "$DATA_DIR/logs.json" ] && echo "   ✅ logs.json: Existe (\$(cat $DATA_DIR/logs.json | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data))") logs)" || echo "   ❌ logs.json: Não existe"
echo ""

# Portas
echo "🌐 Portas:"
netstat -tlnp | grep :5000 && echo "   ✅ Porta 5000: Em uso" || echo "   ❌ Porta 5000: Livre"
echo ""

# Teste de API
echo "🔌 Teste de API:"
if curl -s http://localhost:5000/api/config >/dev/null 2>&1; then
    echo "   ✅ API respondendo"
    echo "   📊 Abas ativas: \$(curl -s http://localhost:5000/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))")"
else
    echo "   ❌ API não respondendo"
fi
echo ""

# Firefox
echo "🦊 Firefox:"
pgrep -f "firefox.*kiosk" >/dev/null && echo "   ✅ Firefox Kiosk: Rodando" || echo "   ❌ Firefox Kiosk: Parado"
echo ""

echo "🏁 Diagnóstico concluído!"
EOF

chmod +x $PROJECT_DIR/diagnose_kiosk.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/diagnose_kiosk.sh

# Script de restauração
print_step "Criando restore_kiosk.sh..."
cat > $PROJECT_DIR/restore_kiosk.sh << EOF
#!/bin/bash

if [ -z "\$1" ]; then
    echo "Uso: \$0 <backup_file.tar.gz>"
    echo ""
    echo "Backups disponíveis:"
    ls -la $BACKUP_DIR/credvision_kiosk_*.tar.gz
    exit 1
fi

BACKUP_FILE="\$1"

if [ ! -f "\$BACKUP_FILE" ]; then
    echo "❌ Arquivo de backup não encontrado: \$BACKUP_FILE"
    exit 1
fi

echo "🔄 Restaurando CrediVision Kiosk..."
echo "📁 Backup: \$BACKUP_FILE"

# Parar serviços
echo "   ⏹️ Parando serviços..."
systemctl stop credvision-app credvision-kiosk || true

# Fazer backup do estado atual
echo "   💾 Criando backup do estado atual..."
CURRENT_BACKUP="$BACKUP_DIR/before_restore_\$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf \$CURRENT_BACKUP \\
    $PROJECT_DIR \\
    $DATA_DIR \\
    $MEDIA_DIR \\
    2>/dev/null || true

# Restaurar backup
echo "   📂 Restaurando arquivos..."
cd /
tar -xzf "\$BACKUP_FILE" 2>/dev/null || true

# Corrigir permissões
echo "   🔧 Corrigindo permissões..."
chown -R $SUDO_USER:$SUDO_USER $DATA_DIR
chown -R $SUDO_USER:$SUDO_USER $MEDIA_DIR
chown -R $SUDO_USER:$SUDO_USER $PROJECT_DIR
chmod 755 $DATA_DIR $MEDIA_DIR

# Reiniciar serviços
echo "   ▶️ Reiniciando serviços..."
systemctl daemon-reload
systemctl start credvision-app
sleep 10
systemctl start credvision-kiosk

echo "✅ Restauração concluída!"
echo "📊 Backup do estado anterior: \$CURRENT_BACKUP"
EOF

chmod +x $PROJECT_DIR/restore_kiosk.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/restore_kiosk.sh

# ETAPA 12: Configurar Auto-login (Opcional)
print_header "ETAPA 12: AUTO-LOGIN GNOME"
print_warning "Auto-login é opcional. Deseja configurar?"
read -p "Configurar auto-login para o usuário $SUDO_USER? (s/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_step "Configurando auto-login..."
    
    # Criar configuração de auto-login
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SUDO_USER --noclear %I \$TERM
EOF
    
    # Configurar GNOME auto-login
    if [ -d "/etc/gdm3" ]; then
        cat > /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$SUDO_USER

[security]

[xdmcp]

[chooser]

[debug]
EOF
        systemctl restart gdm3 || true
    fi
    
    print_status "Auto-login configurado"
else
    print_status "Auto-login não configurado (usuário precisará fazer login manual)"
fi

# ETAPA 13: Iniciar Serviços
print_header "ETAPA 13: INICIALIZAÇÃO FINAL"
print_step "Iniciando serviços CrediVision..."

# Iniciar serviço principal
systemctl start credvision-app

# Aguardar inicialização do Docker
print_status "Aguardando inicialização do Docker..."
sleep 20

# Verificar status do container
if docker ps | grep credvision-app >/dev/null 2>&1; then
    print_status "✅ Container Docker iniciado com sucesso!"
else
    print_error "❌ Falha ao iniciar container Docker"
    docker logs credvision-app
    exit 1
fi

# Aguardar aplicação
print_status "Aguardando aplicação Flask..."
sleep 20

# ETAPA 14: Teste Final
print_header "ETAPA 14: TESTE FINAL"
print_step "Realizando testes de funcionamento..."

# Testar API
if curl -s http://localhost:5000/api/config >/dev/null; then
    print_status "✅ API respondendo corretamente"
    ABAS_COUNT=$(curl -s http://localhost:5000/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))")
    print_status "   📊 Abas configuradas: $ABAS_COUNT"
else
    print_warning "⚠️ API não respondendo (ainda iniciando)"
fi

# Testar arquivos JSON
if [ -f "$DATA_DIR/tabs.json" ]; then
    print_status "✅ Arquivos JSON criados"
else
    print_warning "⚠️ Arquivos JSON não encontrados (serão criados no primeiro acesso)"
fi

# RESUMO FINAL
print_header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo ""
echo -e "${GREEN}✅ CrediVision Kiosk instalado e configurado!${NC}"
echo ""
echo -e "${CYAN}📍 Informações Importantes:${NC}"
echo "   🏠 Projeto: $PROJECT_DIR"
echo "   📁 Dados: $DATA_DIR (arquivos JSON)"
echo "   📁 Mídia: $MEDIA_DIR (imagens/vídeos)"
echo "   📁 Backups: $BACKUP_DIR"
echo "   🌐 Admin: http://$(hostname -I | awk '{print $1}'):5000"
echo "   📺 Display: http://$(hostname -I | awk '{print $1}'):5000/display"
echo ""
echo -e "${CYAN}👤 Credenciais Padrão:${NC}"
echo "   👤 Usuário: admin"
echo "   🔑 Senha: admin123"
echo "   ⚠️  TROQUE A SENHA APÓS PRIMEIRO ACESSO!"
echo ""
echo -e "${CYAN}⏱️ FLUXO DE INICIALIZAÇÃO:${NC}"
echo "   1. 🔌 Ligar computador"
echo "   2. 🚀 Ubuntu boot (15-20s)"
echo "   3. 📋 Tela de carregamento (30s)"
echo "   4. 🐳 Docker inicia app Flask"
echo "   5. 🦊 Firefox abre em modo kiosk"
echo "   6. 📺 Exibe conteúdo configurado"
echo ""
echo -e "${CYAN}🔧 Comandos Úteis:${NC}"
echo "   📊 Status: sudo systemctl status credvision-app"
echo "   📋 Logs: sudo journalctl -u credvision-app -f"
echo "   🔍 Diagnóstico: sudo $PROJECT_DIR/diagnose_kiosk.sh"
echo "   💾 Backup: sudo $PROJECT_DIR/backup_kiosk.sh"
echo "   🔄 Restore: sudo $PROJECT_DIR/restore_kiosk.sh <backup>"
echo ""
echo -e "${CYAN}📁 Estrutura de Persistência:${NC}"
echo "   📄 $DATA_DIR/tabs.json - Configurações das abas"
echo "   👥 $DATA_DIR/users.json - Usuários do sistema"
echo "   📋 $DATA_DIR/logs.json - Logs de auditoria"
echo "   📁 $MEDIA_DIR/ - Imagens e vídeos (NÃO APAGA AO REINICIAR)"
echo ""
echo -e "${CYAN}🎮 Gerenciamento de Serviços:${NC}"
echo "   ▶️ Iniciar: sudo systemctl start credvision-app"
echo "   ⏹️ Parar: sudo systemctl stop credvision-app credvision-kiosk"
echo "   🔄 Reiniciar: sudo systemctl restart credvision-app"
echo "   📺 Kiosk: sudo systemctl restart credvision-kiosk"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE - PERSISTÊNCIA TOTAL:${NC}"
echo "   ✅ Arquivos em ~/Documents/ NUNCA são apagados"
echo "   ✅ Configurações mantidas após reiniciar"
echo "   ✅ Mídia (imagens/vídeos) preservada"
echo "   ✅ Logs e histórico mantidos"
echo ""
echo -e "${CYAN}❓ Deseja reiniciar o sistema agora?${NC}"
read -p "Reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_status "🔄 Reiniciando sistema em 5 segundos..."
    sleep 5
    reboot
else
    print_status "✅ Instalação concluída! Reinicie manualmente quando desejar."
    echo ""
    echo -e "${CYAN}🧪 Para testar sem reiniciar:${NC}"
    echo "   sudo systemctl start credvision-kiosk"
    echo ""
    echo -e "${CYAN}📺 Após reiniciar, o sistema iniciará automaticamente:${NC}"
    echo "   1. Tela de carregamento por 30 segundos"
    echo "   2. Firefox kiosk abrirá automaticamente"
    echo "   3. Conteúdo será exibido na TV"
fi

echo ""
echo -e "${GREEN}🎊 Parabéns! Seu sistema CrediVision Kiosk está pronto!${NC}"
echo -e "${GREEN}📺 A TV exibirá o conteúdo automaticamente ao ligar!${NC}"
echo -e "${GREEN}🔧 Gerencie remotamente via: http://$(hostname -I | awk '{print $1}'):5000${NC}"
