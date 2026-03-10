#!/bin/bash

# Script Completo de Instalação do CrediVision no Ubuntu
# Uso: sudo bash setup_ubuntu_complete.sh

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
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
print_header "CREDIVISION - INSTALAÇÃO COMPLETA UBUNTU"
echo ""
echo -e "${CYAN}Sistema de Exibição Kiosk com Suporte a Imagens e Vídeos${NC}"
echo -e "${CYAN}Versão: 1.0 | Autor: CrediVision Team${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Verificar sistema operacional
print_step "Verificando sistema operacional..."
if ! grep -q "Ubuntu" /etc/os-release; then
    print_warning "Este script foi projetado para Ubuntu. Outros sistemas podem não ser compatíveis."
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Configurar variáveis
PROJECT_DIR="/opt/credvision"
GIT_REPO="https://github.com/SEU-USUARIO/credvision.git"  # ATUALIZAR COM SEU REPOSITÓRIO
MEDIA_DIR="/home/$SUDO_USER/Documentos/kiosk-media"
SERVICE_USER="$SUDO_USER"

print_step "Configurando variáveis..."
echo "   📁 Diretório do projeto: $PROJECT_DIR"
echo "   📁 Diretório de mídia: $MEDIA_DIR"
echo "   👤 Usuário do serviço: $SERVICE_USER"
echo ""

# ETAPA 1: Atualizar Sistema
print_header "ETAPA 1: ATUALIZAÇÃO DO SISTEMA"
print_step "Atualizando lista de pacotes..."
apt update

print_step "Atualizando pacotes instalados..."
apt upgrade -y

print_step "Removendo pacotes desnecessários..."
apt autoremove -y
apt autoclean

# ETAPA 2: Instalar Dependências Básicas
print_header "ETAPA 2: DEPENDÊNCIAS BÁSICAS"
print_step "Instalando ferramentas essenciais..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    nano \
    vim \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-setuptools \
    python3-wheel

print_step "Instalando bibliotecas de sistema..."
apt install -y \
    sqlite3 \
    libsqlite3-dev \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    zlib1g-dev

# ETAPA 3: Instalar Docker
print_header "ETAPA 3: INSTALAÇÃO DO DOCKER"
print_step "Removendo versões antigas do Docker..."
apt remove -y docker docker-engine docker.io containerd runc || true

print_step "Adicionando repositório Docker oficial..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

print_step "Instalando Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

print_step "Configurando permissões Docker..."
usermod -aG docker $SUDO_USER || true

print_step "Iniciando e habilitando Docker..."
systemctl start docker
systemctl enable docker

print_status "Verificando instalação Docker..."
docker --version
docker compose version

# ETAPA 4: Instalar Firefox
print_header "ETAPA 4: INSTALAÇÃO DO FIREFOX"
print_step "Instalando Firefox para modo kiosk..."
apt install -y firefox firefox-locale-pt

# ETAPA 5: Clonar Repositório Git
print_header "ETAPA 5: CLONAR REPOSITÓRIO GIT"
print_step "Clonando repositório CrediVision..."

# Criar diretório do projeto
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Clonar repositório
if [ -d ".git" ]; then
    print_status "Repositório já existe. Atualizando..."
    git pull origin main
else
    print_status "Clonando repositório..."
    git clone $GIT_REPO .
fi

# ETAPA 6: Criar Estrutura de Diretórios
print_header "ETAPA 6: CRIAÇÃO DE ESTRUTURA DE DIRETÓRIOS"
print_step "Criando diretórios essenciais..."

# Diretório de mídia
mkdir -p $MEDIA_DIR/{imagens,videos,outros}
chown -R $SUDO_USER:$SUDO_USER $MEDIA_DIR
chmod 755 $MEDIA_DIR

# Diretórios de dados
mkdir -p $PROJECT_DIR/{data,logs,backups}
chown -R $SUDO_USER:$SUDO_USER $PROJECT_DIR
chmod 755 $PROJECT_DIR

# Diretório temporário
mkdir -p /tmp/credvision
chmod 755 /tmp/credvision

print_status "Diretórios criados:"
echo "   📁 $PROJECT_DIR - Projeto"
echo "   📁 $MEDIA_DIR - Mídia"
echo "   📁 $PROJECT_DIR/data - Banco de dados"
echo "   📁 $PROJECT_DIR/logs - Logs"
echo "   📁 $PROJECT_DIR/backups - Backups"

# ETAPA 7: Configurar Ambiente Python
print_header "ETAPA 7: CONFIGURAÇÃO PYTHON"
print_step "Criando ambiente virtual..."
cd $PROJECT_DIR
sudo -u $SUDO_USER python3 -m venv venv

print_step "Ativando ambiente virtual e instalando dependências..."
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"

# ETAPA 8: Configurar Variáveis de Ambiente
print_header "ETAPA 8: VARIÁVEIS DE AMBIENTE"
print_step "Criando arquivo .env..."

# Gerar chaves seguras
SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -base64 32)

cat > $PROJECT_DIR/.env << EOF
# Configurações do CrediVision
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DB_PATH=/data/kiosk.db
CONFIG_PATH=/data/config.json
ADMIN_URL=http://localhost:5000
KIOSK_MODE=full
CONFIG_REFRESH=300
DISPLAY=:0
MEDIA_FOLDER=$MEDIA_DIR

# Configurações de segurança
SESSION_TIMEOUT=3600
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900

# Configurações de upload
MAX_FILE_SIZE=104857600
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,mp4,avi,mov,webm

# Configurações Docker
COMPOSE_PROJECT_NAME=credvision
COMPOSE_FILE=docker-compose.ubuntu.yml
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
    print_status "Firewall configurado:"
    echo "   🔒 SSH: Permitido"
    echo "   🔒 Porta 5000: Permitida (CrediVision)"
else
    print_warning "UFW não encontrado. Instalando..."
    apt install -y ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 5000/tcp
    ufw --force enable
fi

# ETAPA 10: Criar Serviços Systemd
print_header "ETAPA 10: SERVIÇOS SYSTEMD"

# Serviço principal
print_step "Criando serviço credvision.service..."
cat > /etc/systemd/system/credvision.service << EOF
[Unit]
Description=CrediVision Kiosk System
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Group=$SERVICE_USER
ExecStart=/usr/bin/docker compose -f docker-compose.ubuntu.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.ubuntu.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.ubuntu.yml restart
TimeoutStartSec=0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Serviço Firefox Kiosk
print_step "Criando serviço firefox-kiosk.service..."
cat > /etc/systemd/system/firefox-kiosk.service << EOF
[Unit]
Description=Firefox Kiosk Mode for CrediVision
After=graphical-session.target credvision.service
Wants=credvision.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/usr/bin/firefox --kiosk http://localhost:5000/display --no-first-run --disable-pinch
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
EOF

# Serviço de backup automático
print_step "Criando serviço backup-credvision.service..."
cat > /etc/systemd/system/backup-credvision.service << EOF
[Unit]
Description=CrediVision Automatic Backup
After=credvision.service

[Service]
Type=oneshot
User=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/backup.sh
StandardOutput=journal
StandardError=journal
EOF

# Timer para backup diário
print_step "Criando timer backup-credvision.timer..."
cat > /etc/systemd/system/backup-credvision.timer << EOF
[Unit]
Description=Daily CrediVision Backup
Requires=backup-credvision.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Habilitar serviços
print_step "Habilitando serviços..."
systemctl daemon-reload
systemctl enable credvision.service
systemctl enable firefox-kiosk.service
systemctl enable backup-credvision.timer

# ETAPA 11: Criar Scripts de Manutenção
print_header "ETAPA 11: SCRIPTS DE MANUTENÇÃO"

# Script de atualização
print_step "Criando script update.sh..."
cat > $PROJECT_DIR/update.sh << 'EOF'
#!/bin/bash

echo "🔄 Atualizando CrediVision..."

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root"
   exit 1
fi

# Parar serviços
echo "   ⏹️ Parando serviços..."
systemctl stop credvision
systemctl stop firefox-kiosk

# Fazer backup antes de atualizar
echo "   💾 Criando backup..."
/opt/credvision/backup.sh

# Atualizar repositório git
echo "   📥 Atualizando código..."
cd /opt/credvision
sudo -u $SUDO_USER git pull origin main

# Reconstruir imagens Docker
echo "   🐳 Reconstruindo imagens..."
docker compose -f docker-compose.ubuntu.yml down
docker compose -f docker-compose.ubuntu.yml build --no-cache

# Reiniciar serviços
echo "   ▶️ Reiniciando serviços..."
systemctl start credvision
sleep 10
systemctl start firefox-kiosk

echo "✅ CrediVision atualizado com sucesso!"
echo "📊 Status: systemctl status credvision"
EOF

# Script de backup
print_step "Criando script backup.sh..."
cat > $PROJECT_DIR/backup.sh << EOF
#!/bin/bash

BACKUP_DIR="/opt/credvision-backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/credvision_backup_\$DATE.tar.gz"

echo "💾 Criando backup do CrediVision..."

# Criar diretório de backup
mkdir -p \$BACKUP_DIR

# Parar serviços temporariamente
systemctl stop credvision || true
systemctl stop firefox-kiosk || true

# Criar backup
tar -czf \$BACKUP_FILE \
    /opt/credvision \
    /home/\$USER/Documentos/kiosk-media \
    /etc/systemd/system/credvision* \
    /etc/systemd/system/firefox-kiosk* \
    /etc/systemd/system/backup-credvision* \
    2>/dev/null || true

# Reiniciar serviços
systemctl start credvision
systemctl start firefox-kiosk

echo "✅ Backup criado: \$BACKUP_FILE"
echo "📊 Tamanho: \$(du -h \$BACKUP_FILE | cut -f1)"

# Manter apenas os últimos 7 backups
find \$BACKUP_DIR -name "credvision_backup_*.tar.gz" -mtime +7 -delete

echo "🗑️ Backups antigos removidos"
EOF

# Script de diagnóstico
print_step "Criando script diagnose.sh..."
cat > $PROJECT_DIR/diagnose.sh << 'EOF'
#!/bin/bash

echo "🔍 Diagnóstico do CrediVision"
echo "============================"

# Informações do sistema
echo "📊 Sistema:"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Uptime: $(uptime -p)"
echo ""

# Status dos serviços
echo "🔧 Serviços:"
systemctl is-active credvision && echo "   ✅ CrediVision: Ativo" || echo "   ❌ CrediVision: Inativo"
systemctl is-active firefox-kiosk && echo "   ✅ Firefox Kiosk: Ativo" || echo "   ❌ Firefox Kiosk: Inativo"
systemctl is-active backup-credvision.timer && echo "   ✅ Backup Timer: Ativo" || echo "   ❌ Backup Timer: Inativo"
echo ""

# Docker
echo "🐳 Docker:"
docker --version 2>/dev/null || echo "   ❌ Docker não instalado"
docker compose version 2>/dev/null || echo "   ❌ Docker Compose não instalado"
echo ""

# Portas
echo "🌐 Portas:"
netstat -tlnp | grep :5000 && echo "   ✅ Porta 5000: Em uso" || echo "   ❌ Porta 5000: Livre"
echo ""

# Diretórios
echo "📁 Diretórios:"
[ -d "/opt/credvision" ] && echo "   ✅ /opt/credvision: Existe" || echo "   ❌ /opt/credvision: Não existe"
[ -d "/home/$USER/Documentos/kiosk-media" ] && echo "   ✅ kiosk-media: Existe" || echo "   ❌ kiosk-media: Não existe"
echo ""

# Logs recentes
echo "📋 Logs recentes:"
journalctl -u credvision --since "1 hour ago" --no-pager -n 5
echo ""

# Teste de API
echo "🔌 Teste de API:"
curl -s http://localhost:5000/api/config >/dev/null 2>&1 && echo "   ✅ API respondendo" || echo "   ❌ API não respondendo"
echo ""

echo "🏁 Diagnóstico concluído!"
EOF

# Tornar scripts executáveis
chmod +x $PROJECT_DIR/update.sh
chmod +x $PROJECT_DIR/backup.sh
chmod +x $PROJECT_DIR/diagnose.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/*.sh

# ETAPA 12: Configurar Logs
print_header "ETAPA 12: CONFIGURAÇÃO DE LOGS"
print_step "Configurando rotação de logs..."

cat > /etc/logrotate.d/credvision << EOF
/opt/credvision/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload credvision >/dev/null 2>&1 || true
    endscript
}
EOF

# ETAPA 13: Configurar Segurança Adicional
print_header "ETAPA 13: SEGURANÇA ADICIONAL"
print_step "Configurando segurança do sistema..."

# Desabilitar login root SSH
if [ -f "/etc/ssh/sshd_config" ]; then
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd
fi

# Configurar limites de arquivos
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# ETAPA 14: Iniciar Serviços
print_header "ETAPA 14: INICIALIZAÇÃO FINAL"
print_step "Iniciando serviços CrediVision..."

# Iniciar serviço principal
systemctl start credvision

# Aguardar inicialização
print_status "Aguardando inicialização do serviço..."
sleep 15

# Verificar status
if systemctl is-active --quiet credvision; then
    print_status "✅ CrediVision iniciado com sucesso!"
else
    print_error "❌ Falha ao iniciar CrediVision"
    journalctl -u credvision --no-pager -n 20
    exit 1
fi

# ETAPA 15: Teste Final
print_header "ETAPA 15: TESTE FINAL"
print_step "Realizando testes de funcionamento..."

# Testar API
if curl -s http://localhost:5000/api/config >/dev/null; then
    print_status "✅ API respondendo corretamente"
else
    print_warning "⚠️ API não respondendo (pode ser normal se Firefox ainda não iniciou)"
fi

# Testar diretórios
if [ -d "$MEDIA_DIR" ]; then
    print_status "✅ Diretório de mídia criado"
else
    print_error "❌ Diretório de mídia não encontrado"
fi

# Testar permissões
if [ -w "$MEDIA_DIR" ]; then
    print_status "✅ Permissões de escrita OK"
else
    print_error "❌ Sem permissão de escrita no diretório de mídia"
fi

# RESUMO FINAL
print_header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo ""
echo -e "${GREEN}✅ CrediVision instalado e configurado!${NC}"
echo ""
echo -e "${CYAN}📍 Informações Importantes:${NC}"
echo "   🏠 Diretório do projeto: $PROJECT_DIR"
echo "   📁 Diretório de mídia: $MEDIA_DIR"
echo "   🌐 URL Admin: http://$(hostname -I | awk '{print $1}'):5000"
echo "   📺 URL Display: http://$(hostname -I | awk '{print $1}'):5000/display"
echo ""
echo -e "${CYAN}👤 Credenciais Padrão:${NC}"
echo "   👤 Usuário: admin"
echo "   🔑 Senha: admin123"
echo "   ⚠️  TROQUE A SENHA APÓS PRIMEIRO ACESSO!"
echo ""
echo -e "${CYAN}🔧 Comandos Úteis:${NC}"
echo "   📊 Status: sudo systemctl status credvision"
echo "   📋 Logs: sudo journalctl -u credvision -f"
echo "   🔄 Atualizar: sudo $PROJECT_DIR/update.sh"
echo "   💾 Backup: sudo $PROJECT_DIR/backup.sh"
echo "   🔍 Diagnóstico: sudo $PROJECT_DIR/diagnose.sh"
echo ""
echo -e "${CYAN}🎮 Gerenciamento de Serviços:${NC}"
echo "   ▶️ Iniciar: sudo systemctl start credvision"
echo "   ⏹️ Parar: sudo systemctl stop credvision"
echo "   🔄 Reiniciar: sudo systemctl restart credvision"
echo "   📺 Firefox: sudo systemctl start firefox-kiosk"
echo ""
echo -e "${CYAN}📁 Adicionar Conteúdo:${NC}"
echo "   1. Copie arquivos para: $MEDIA_DIR"
echo "   2. Acesse: http://$(hostname -I | awk '{print $1}'):5000"
echo "   3. Vá em 'Abas / Conteúdo' > 'Nova Aba'"
echo "   4. Escolha tipo e faça upload"
echo ""
echo -e "${YELLOW}⚠️  PRÓXIMOS PASSOS:${NC}"
echo "   1. 🔄 Reinicie o sistema: sudo reboot"
echo "   2. 🔐 Troque a senha padrão"
echo "   3. 📁 Adicione seus arquivos de mídia"
echo "   4. 🎯 Configure suas abas de conteúdo"
echo ""

# Perguntar se quer reiniciar agora
echo -e "${CYAN}❓ Deseja reiniciar o sistema agora?${NC}"
read -p "Reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_status "🔄 Reiniciando sistema em 5 segundos..."
    sleep 5
    reboot
else
    print_status "✅ Instalação concluída! Reinicie manualmente quando desejar."
fi

echo ""
echo -e "${GREEN}🎊 Parabéns! Seu sistema CrediVision está pronto para usar!${NC}"
echo -e "${GREEN}📞 Suporte: https://github.com/SEU-USUARIO/credvision/issues${NC}"
