#!/bin/bash

# Script de Instalação Local - CrediVision Ubuntu
# Uso: sudo bash setup_ubuntu_local.sh
# Assume que o repositório já está clonado

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
    echo -e "${PURPLE}║${NC} ${CYAN}CREDIVISION - INSTALAÇÃO LOCAL UBUNTU${NC} ${PURPLE}$(printf "%*s" $((64 - 37)) "")${PURPLE}║${NC}"
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
print_header
echo ""
echo -e "${CYAN}Instalação completa do CrediVision (repositório local)${NC}"
echo -e "${CYAN}Configura Docker, Systemd, Kiosk e inicialização automática${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Verificar se estamos no diretório correto
if [ ! -f "app_no_db.py" ] && [ ! -f "app.py" ]; then
    print_error "Execute este script no diretório raiz do CrediVision"
    print_error "Arquivos app_no_db.py ou app.py não encontrados"
    exit 1
fi

# Configurar variáveis
PROJECT_DIR="$(pwd)"
SERVICE_USER="$SUDO_USER"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"
APP_PORT="5000"

print_step "Configuração detectada:"
echo "   📁 Projeto: $PROJECT_DIR"
echo "   👤 Usuário: $SERVICE_USER"
echo "   📁 Dados: $DATA_DIR"
echo "   📁 Mídia: $MEDIA_DIR"
echo "   🌐 Porta: $APP_PORT"
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
    x11-xserver-utils \
    net-tools

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
usermod -aG docker $SERVICE_USER || true
systemctl start docker
systemctl enable docker

# ETAPA 4: Criar Estrutura de Diretórios
print_header "ETAPA 4: ESTRUTURA DE DIRETÓRIOS"
print_step "Criando diretórios essenciais..."

mkdir -p "$DATA_DIR"
mkdir -p "$MEDIA_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$PROJECT_DIR/logs"

# Criar subdiretórios de mídia
mkdir -p "$MEDIA_DIR/imagens"
mkdir -p "$MEDIA_DIR/videos"
mkdir -p "$MEDIA_DIR/outros"

chown -R $SERVICE_USER:$SERVICE_USER "$DATA_DIR"
chown -R $SERVICE_USER:$SERVICE_USER "$MEDIA_DIR"
chown -R $SERVICE_USER:$SERVICE_USER "$BACKUP_DIR"
chown -R $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR"

chmod 755 "$DATA_DIR"
chmod 755 "$MEDIA_DIR"
chmod 755 "$BACKUP_DIR"

print_status "Diretórios criados:"
echo "   📁 $PROJECT_DIR - Projeto"
echo "   📁 $DATA_DIR - Dados JSON"
echo "   📁 $MEDIA_DIR - Arquivos de mídia"
echo "   📁 $BACKUP_DIR - Backups automáticos"

# ETAPA 5: Configurar Ambiente Python
print_header "ETAPA 5: CONFIGURAÇÃO PYTHON"
print_step "Criando ambiente virtual..."
cd "$PROJECT_DIR"
sudo -u $SERVICE_USER python3 -m venv venv

print_step "Instalando dependências..."
sudo -u $SERVICE_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u $SERVICE_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"

# ETAPA 6: Criar Docker Compose
print_header "ETAPA 6: CONFIGURAÇÃO DOCKER COMPOSE"
print_step "Criando docker-compose.yml..."

cat > "$PROJECT_DIR/docker-compose.yml" << EOF
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
      - ADMIN_URL=http://localhost:$APP_PORT
      - KIOSK_MODE=app-only
      - CONFIG_REFRESH=300
    ports:
      - "$APP_PORT:5000"
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
cat > "$PROJECT_DIR/Dockerfile" << EOF
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

# ETAPA 7: Configurar Variáveis de Ambiente
print_header "ETAPA 7: VARIÁVEIS DE AMBIENTE"
print_step "Criando arquivo .env..."

SECRET_KEY=$(openssl rand -hex 32)

cat > "$PROJECT_DIR/.env" << EOF
# Configurações do CrediVision Kiosk
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
ADMIN_URL=http://localhost:$APP_PORT
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

chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/.env"
chmod 600 "$PROJECT_DIR/.env"

# ETAPA 8: Configurar Firewall
print_header "ETAPA 8: CONFIGURAÇÃO DE FIREWALL"
if command -v ufw >/dev/null 2>&1; then
    print_step "Configurando UFW..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow $APP_PORT/tcp
    ufw --force enable
    print_status "Firewall configurado"
else
    print_warning "UFW não encontrado"
fi

# ETAPA 9: Criar Services Systemd
print_header "ETAPA 9: SERVIÇOS SYSTEMD (INÍCIO AUTOMÁTICO)"

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
ExecStart=/usr/bin/zenity --info --title="CrediVision Kiosk" --text="\\n<b>CrediVision Kiosk</b>\\n\\n🚀 Iniciando sistema...\\n\\n⏱️ Aguarde 30 segundos para o kiosk abrir\\n\\n📺 O conteúdo será exibido automaticamente\\n\\n🔧 Acesso admin: http://$(hostname -I | awk '{print $1}'):$APP_PORT\\n\\n👤 Login: admin / admin123" --timeout=30 --width=500 --height=300
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
ExecStart=/bin/bash -c 'sleep 30 && /usr/bin/firefox --kiosk http://localhost:$APP_PORT/display --no-first-run --disable-pinch --disable-infobars'
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

# Habilitar serviços para início automático
print_step "Habilitando serviços para início automático..."
systemctl daemon-reload
systemctl enable credvision-app.service
systemctl enable credvision-boot.service
systemctl enable credvision-kiosk.service
systemctl enable credvision-backup.timer

# ETAPA 10: Criar Scripts de Manutenção
print_header "ETAPA 10: SCRIPTS DE MANUTENÇÃO"

# Script de backup
print_step "Criando backup_kiosk.sh..."
cat > "$PROJECT_DIR/backup_kiosk.sh" << EOF
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
    "$PROJECT_DIR" \\
    "$DATA_DIR" \\
    "$MEDIA_DIR" \\
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

chmod +x "$PROJECT_DIR/backup_kiosk.sh"
chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/backup_kiosk.sh"

# Script de diagnóstico
print_step "Criando diagnose_kiosk.sh..."
cat > "$PROJECT_DIR/diagnose_kiosk.sh" << EOF
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
netstat -tlnp | grep :$APP_PORT && echo "   ✅ Porta $APP_PORT: Em uso" || echo "   ❌ Porta $APP_PORT: Livre"
echo ""

# Teste de API
echo "🔌 Teste de API:"
if curl -s http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    echo "   ✅ API respondendo"
    echo "   📊 Abas ativas: \$(curl -s http://localhost:$APP_PORT/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))")"
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

chmod +x "$PROJECT_DIR/diagnose_kiosk.sh"
chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/diagnose_kiosk.sh"

# ETAPA 11: Configurar Auto-login (Opcional)
print_header "ETAPA 11: AUTO-LOGIN GNOME"
print_warning "Auto-login é opcional. Deseja configurar?"
read -p "Configurar auto-login para o usuário $SERVICE_USER? (s/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_step "Configurando auto-login..."
    
    # Criar configuração de auto-login
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $SERVICE_USER --noclear %I \$TERM
EOF
    
    # Configurar GNOME auto-login
    if [ -d "/etc/gdm3" ]; then
        cat > /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$SERVICE_USER

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

# ETAPA 12: Iniciar Serviços
print_header "ETAPA 12: INICIALIZAÇÃO FINAL"
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

# ETAPA 13: Criar Usuário Admin
print_header "ETAPA 13: CONFIGURAÇÃO USUÁRIO ADMIN"
print_step "Criando usuário admin padrão..."

# Verificar se o arquivo users.json existe
if [ ! -f "$DATA_DIR/users.json" ]; then
    echo "[]" > "$DATA_DIR/users.json"
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR/users.json"
    chmod 644 "$DATA_DIR/users.json"
fi

# Criar usuário admin
python3 << EOF
import json
import hashlib
from datetime import datetime

# Configurações
username = "admin"
password = "admin123"
users_file = "$DATA_DIR/users.json"

# Gerar hash da senha
password_hash = hashlib.sha256(f"kiosk_salt_2024{password}".encode()).hexdigest()

# Gerar timestamp
timestamp = datetime.utcnow().isoformat() + 'Z'

# Ler usuários existentes
try:
    with open(users_file, 'r') as f:
        users = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    users = []

# Remover admin existente (se houver)
users = [u for u in users if u.get('username') != username]

# Criar novo admin
new_admin = {
    "id": max([u.get('id', 0) for u in users] + [0]) + 1,
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": timestamp
}
users.append(new_admin)

# Salvar
with open(users_file, 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"✅ Usuário admin criado!")
print(f"👤 Usuário: {username}")
print(f"🔑 Senha: {password}")
print(f"📊 Total de usuários: {len(users)}")
EOF

if [ $? -eq 0 ]; then
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR/users.json"
    chmod 644 "$DATA_DIR/users.json"
    print_status "✅ Usuário admin criado com sucesso!"
else
    print_warning "⚠️ Falha ao criar usuário admin (crie manualmente)"
fi

# ETAPA 14: Teste Final
print_header "ETAPA 14: TESTE FINAL"
print_step "Realizando testes de funcionamento..."

# Testar API
if curl -s http://localhost:$APP_PORT/api/config >/dev/null; then
    print_status "✅ API respondendo corretamente"
    ABAS_COUNT=$(curl -s http://localhost:$APP_PORT/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))")
    print_status "   📊 Abas configuradas: $ABAS_COUNT"
else
    print_warning "⚠️ API não respondendo (ainda iniciando)"
fi

# Obter IP do sistema
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# RESUMO FINAL
print_header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo ""
echo -e "${GREEN}✅ CrediVision instalado e configurado!${NC}"
echo ""
echo -e "${CYAN}📍 Informações Importantes:${NC}"
echo "   🏠 Projeto: $PROJECT_DIR"
echo "   📁 Dados: $DATA_DIR (arquivos JSON)"
echo "   📁 Mídia: $MEDIA_DIR (imagens/vídeos)"
echo "   📁 Backups: $BACKUP_DIR"
echo "   🌐 Admin: http://$IP_ADDRESS:$APP_PORT"
echo "   📺 Display: http://$IP_ADDRESS:$APP_PORT/display"
echo ""
echo -e "${CYAN}👤 Credenciais Padrão:${NC}"
echo "   👤 Usuário: admin"
echo "   🔑 Senha: admin123"
echo "   ⚠️  TROQUE A SENHA APÓS PRIMEIRO ACESSO!"
echo ""
echo -e "${CYAN}🔧 CONFIGURAÇÕES DE INÍCIO AUTOMÁTICO:${NC}"
echo "   ✅ Docker: Habilitado para iniciar com o sistema"
echo "   ✅ CrediVision App: Habilitado para iniciar automaticamente"
echo "   ✅ CrediVision Kiosk: Habilitado para iniciar automaticamente"
echo "   ✅ Backup Diário: Configurado e habilitado"
echo ""
echo -e "${CYAN}⏱️ FLUXO DE INICIALIZAÇÃO AUTOMÁTICA:${NC}"
echo "   1. 🔌 Ligar computador"
echo "   2. 🚀 Ubuntu boot (15-20s)"
echo "   3. 📋 Tela de carregamento (30s)"
echo "   4. 🐳 Docker inicia app Flask"
echo "   5. 🦊 Firefox abre em modo kiosk"
echo "   6. 📺 Exibe conteúdo configurado"
echo ""
echo -e "${CYAN}🌐 PORTA DE SERVIÇO:${NC}"
echo "   🚪 Porta: $APP_PORT (configurada no docker-compose.yml)"
echo "   🔧 Para alterar: edite docker-compose.yml e reinicie serviços"
echo ""
echo -e "${CYAN}🦊 CONFIGURAÇÃO KIOSK:${NC}"
echo "   ✅ Firefox Kiosk: Já configurado no script"
echo "   📺 URL: http://localhost:$APP_PORT/display"
echo "   ⏱️ Delay: 30 segundos após início do app"
echo "   🔄 Restart: Automático em caso de falha"
echo ""
echo -e "${CYAN}🔧 Comandos Úteis:${NC}"
echo "   📊 Status: sudo systemctl status credvision-app"
echo "   📋 Logs: sudo journalctl -u credvision-app -f"
echo "   🔍 Diagnóstico: sudo $PROJECT_DIR/diagnose_kiosk.sh"
echo "   💾 Backup: sudo $PROJECT_DIR/backup_kiosk.sh"
echo "   🔄 Restart: sudo systemctl restart credvision-app credvision-kiosk"
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
echo -e "${GREEN}🎊 Parabéns! Seu sistema CrediVision está pronto!${NC}"
echo -e "${GREEN}📺 A TV exibirá o conteúdo automaticamente ao ligar!${NC}"
echo -e "${GREEN}🌐 Acesse remotamente: http://$IP_ADDRESS:$APP_PORT${NC}"
echo -e "${GREEN}🔧 Sistema configurado para início automático!${NC}"
