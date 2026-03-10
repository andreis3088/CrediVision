#!/bin/bash

# Script Completo de Instalação - CrediVision SEM BANCO DE DADOS
# Uso: sudo bash setup_ubuntu_no_db.sh

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
print_header "CREDIVISION SEM BANCO DE DADOS - INSTALAÇÃO UBUNTU"
echo ""
echo -e "${CYAN}Sistema de Exibição Kiosk com Armazenamento Local${NC}"
echo -e "${CYAN}Versão: 1.0 | Armazenamento: Arquivos JSON${NC}"
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
SERVICE_USER="$SUDO_USER"

print_step "Configurando variáveis..."
echo "   📁 Projeto: $PROJECT_DIR"
echo "   📁 Dados: $DATA_DIR"
echo "   📁 Mídia: $MEDIA_DIR"
echo "   👤 Usuário: $SERVICE_USER"
echo ""

# ETAPA 1: Atualizar Sistema
print_header "ETAPA 1: ATUALIZAÇÃO DO SISTEMA"
print_step "Atualizando sistema..."
apt update && apt upgrade -y

# ETAPA 2: Instalar Dependências
print_header "ETAPA 2: DEPENDÊNCIAS"
print_step "Instalando ferramentas essenciais..."
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
    firefox

# ETAPA 3: Clonar Repositório
print_header "ETAPA 3: CLONAR REPOSITÓRIO"
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

# ETAPA 4: Criar Estrutura de Diretórios
print_header "ETAPA 4: ESTRUTURA DE DIRETÓRIOS"
print_step "Criando diretórios essenciais..."

mkdir -p "$DATA_DIR"
mkdir -p "$MEDIA_DIR"
mkdir -p "$PROJECT_DIR/logs"

chown -R $SUDO_USER:$SUDO_USER "$DATA_DIR"
chown -R $SUDO_USER:$SUDO_USER "$MEDIA_DIR"
chown -R $SUDO_USER:$SUDO_USER "$PROJECT_DIR"

chmod 755 "$DATA_DIR"
chmod 755 "$MEDIA_DIR"

print_status "Diretórios criados:"
echo "   📁 $PROJECT_DIR - Projeto"
echo "   📁 $DATA_DIR - Dados JSON"
echo "   📁 $MEDIA_DIR - Arquivos de mídia"

# ETAPA 5: Configurar Ambiente Python
print_header "ETAPA 5: CONFIGURAÇÃO PYTHON"
print_step "Criando ambiente virtual..."
cd $PROJECT_DIR
sudo -u $SUDO_USER python3 -m venv venv

print_step "Instalando dependências..."
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install --upgrade pip"
sudo -u $SUDO_USER bash -c "source venv/bin/activate && pip install -r requirements.txt"

# ETAPA 6: Configurar Variáveis de Ambiente
print_header "ETAPA 6: VARIÁVEIS DE AMBIENTE"
print_step "Criando arquivo .env..."

SECRET_KEY=$(openssl rand -hex 32)

cat > $PROJECT_DIR/.env << EOF
# Configurações do CrediVision (SEM BANCO DE DADOS)
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=$DATA_DIR
MEDIA_FOLDER=$MEDIA_DIR
ADMIN_URL=http://localhost:5000
KIOSK_MODE=full
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
TABS_FILE=$DATA_DIR/tabs.json
USERS_FILE=$DATA_DIR/users.json
LOGS_FILE=$DATA_DIR/logs.json
EOF

chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/.env
chmod 600 $PROJECT_DIR/.env

# ETAPA 7: Configurar Firewall
print_header "ETAPA 7: CONFIGURAÇÃO DE FIREWALL"
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

# ETAPA 8: Criar Serviço Systemd
print_header "ETAPA 8: SERVIÇO SYSTEMD"
print_step "Criando serviço credvision-no-db.service..."

cat > /etc/systemd/system/credvision-no-db.service << EOF
[Unit]
Description=CrediVision Kiosk System (No Database)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=$PROJECT_DIR/venv/bin/python app_no_db.py
Restart=always
RestartSec=5
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
After=graphical-session.target credvision-no-db.service
Wants=credvision-no-db.service

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

# Habilitar serviços
print_step "Habilitando serviços..."
systemctl daemon-reload
systemctl enable credvision-no-db.service
systemctl enable firefox-kiosk.service

# ETAPA 9: Criar Scripts de Manutenção
print_header "ETAPA 9: SCRIPTS DE MANUTENÇÃO"

# Script de backup
print_step "Criando script backup.sh..."
cat > $PROJECT_DIR/backup_no_db.sh << EOF
#!/bin/bash

BACKUP_DIR="/opt/credvision-backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/credvision_no_db_backup_\$DATE.tar.gz"

echo "💾 Criando backup do CrediVision (No DB)..."

# Criar diretório de backup
mkdir -p \$BACKUP_DIR

# Parar serviços
systemctl stop credvision-no-db || true
systemctl stop firefox-kiosk || true

# Criar backup
tar -czf \$BACKUP_FILE \
    $PROJECT_DIR \
    $DATA_DIR \
    $MEDIA_DIR \
    /etc/systemd/system/credvision-no-db.service \
    /etc/systemd/system/firefox-kiosk.service \
    2>/dev/null || true

# Reiniciar serviços
systemctl start credvision-no-db
systemctl start firefox-kiosk

echo "✅ Backup criado: \$BACKUP_FILE"
echo "📊 Tamanho: \$(du -h \$BACKUP_FILE | cut -f1)"

# Manter apenas os últimos 7 backups
find \$BACKUP_DIR -name "credvision_no_db_backup_*.tar.gz" -mtime +7 -delete
EOF

chmod +x $PROJECT_DIR/backup_no_db.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/backup_no_db.sh

# Script de diagnóstico
print_step "Criando script diagnose.sh..."
cat > $PROJECT_DIR/diagnose_no_db.sh << EOF
#!/bin/bash

echo "🔍 Diagnóstico do CrediVision (No DB)"
echo "===================================="

# Informações do sistema
echo "📊 Sistema:"
echo "   OS: \$(lsb_release -d | cut -f2)"
echo "   Kernel: \$(uname -r)"
echo "   Uptime: \$(uptime -p)"
echo ""

# Status dos serviços
echo "🔧 Serviços:"
systemctl is-active credvision-no-db && echo "   ✅ CrediVision: Ativo" || echo "   ❌ CrediVision: Inativo"
systemctl is-active firefox-kiosk && echo "   ✅ Firefox Kiosk: Ativo" || echo "   ❌ Firefox Kiosk: Inativo"
echo ""

# Diretórios
echo "📁 Diretórios:"
[ -d "$PROJECT_DIR" ] && echo "   ✅ Projeto: Existe" || echo "   ❌ Projeto: Não existe"
[ -d "$DATA_DIR" ] && echo "   ✅ Dados: Existe" || echo "   ❌ Dados: Não existe"
[ -d "$MEDIA_DIR" ] && echo "   ✅ Mídia: Existe" || echo "   ❌ Mídia: Não existe"
echo ""

# Arquivos JSON
echo "📋 Arquivos JSON:"
[ -f "$DATA_DIR/tabs.json" ] && echo "   ✅ tabs.json: Existe (\$(cat $DATA_DIR/tabs.json | jq '. | length') abas)" || echo "   ❌ tabs.json: Não existe"
[ -f "$DATA_DIR/users.json" ] && echo "   ✅ users.json: Existe (\$(cat $DATA_DIR/users.json | jq '. | length') usuários)" || echo "   ❌ users.json: Não existe"
[ -f "$DATA_DIR/logs.json" ] && echo "   ✅ logs.json: Existe (\$(cat $DATA_DIR/logs.json | jq '. | length') logs)" || echo "   ❌ logs.json: Não existe"
echo ""

# Portas
echo "🌐 Portas:"
netstat -tlnp | grep :5000 && echo "   ✅ Porta 5000: Em uso" || echo "   ❌ Porta 5000: Livre"
echo ""

# Teste de API
echo "🔌 Teste de API:"
curl -s http://localhost:5000/api/config >/dev/null 2>&1 && echo "   ✅ API respondendo" || echo "   ❌ API não respondendo"
echo ""

echo "🏁 Diagnóstico concluído!"
EOF

chmod +x $PROJECT_DIR/diagnose_no_db.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/diagnose_no_db.sh

# ETAPA 10: Iniciar Serviços
print_header "ETAPA 10: INICIALIZAÇÃO FINAL"
print_step "Iniciando serviços CrediVision..."

systemctl start credvision-no-db

# Aguardar inicialização
print_status "Aguardando inicialização..."
sleep 10

# Verificar status
if systemctl is-active --quiet credvision-no-db; then
    print_status "✅ CrediVision iniciado com sucesso!"
else
    print_error "❌ Falha ao iniciar CrediVision"
    journalctl -u credvision-no-db --no-pager -n 20
    exit 1
fi

# ETAPA 11: Teste Final
print_header "ETAPA 11: TESTE FINAL"
print_step "Realizando testes de funcionamento..."

# Testar API
if curl -s http://localhost:5000/api/config >/dev/null; then
    print_status "✅ API respondendo corretamente"
else
    print_warning "⚠️ API não respondendo"
fi

# Testar arquivos JSON
if [ -f "$DATA_DIR/tabs.json" ]; then
    print_status "✅ Arquivos JSON criados"
else
    print_error "❌ Arquivos JSON não encontrados"
fi

# RESUMO FINAL
print_header "🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo ""
echo -e "${GREEN}✅ CrediVision (No DB) instalado e configurado!${NC}"
echo ""
echo -e "${CYAN}📍 Informações Importantes:${NC}"
echo "   🏠 Projeto: $PROJECT_DIR"
echo "   📁 Dados: $DATA_DIR (arquivos JSON)"
echo "   📁 Mídia: $MEDIA_DIR"
echo "   🌐 Admin: http://$(hostname -I | awk '{print $1}'):5000"
echo "   📺 Display: http://$(hostname -I | awk '{print $1}'):5000/display"
echo ""
echo -e "${CYAN}👤 Credenciais Padrão:${NC}"
echo "   👤 Usuário: admin"
echo "   🔑 Senha: admin123"
echo "   ⚠️  TROQUE A SENHA APÓS PRIMEIRO ACESSO!"
echo ""
echo -e "${CYAN}🔧 Comandos Úteis:${NC}"
echo "   📊 Status: sudo systemctl status credvision-no-db"
echo "   📋 Logs: sudo journalctl -u credvision-no-db -f"
echo "   💾 Backup: sudo $PROJECT_DIR/backup_no_db.sh"
echo "   🔍 Diagnóstico: sudo $PROJECT_DIR/diagnose_no_db.sh"
echo ""
echo -e "${CYAN}📁 Estrutura de Arquivos:${NC}"
echo "   📄 $DATA_DIR/tabs.json - Abas configuradas"
echo "   👥 $DATA_DIR/users.json - Usuários do sistema"
echo "   📋 $DATA_DIR/logs.json - Logs de auditoria"
echo "   📁 $MEDIA_DIR/ - Imagens e vídeos"
echo ""
echo -e "${CYAN}🎮 Gerenciamento:${NC}"
echo "   ▶️ Iniciar: sudo systemctl start credvision-no-db"
echo "   ⏹️ Parar: sudo systemctl stop credvision-no-db"
echo "   🔄 Reiniciar: sudo systemctl restart credvision-no-db"
echo "   📺 Firefox: sudo systemctl start firefox-kiosk"
echo ""
echo -e "${YELLOW}⚠️  VANTAGENS SEM BANCO DE DADOS:${NC}"
echo "   ✅ Sem dependência de banco de dados"
echo "   ✅ Backup simples (copiar pasta)"
echo "   ✅ Portabilidade total"
echo "   ✅ Configuração via arquivos JSON"
echo "   ✅ Exclusão segura de arquivos"
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
fi

echo ""
echo -e "${GREEN}🎊 Parabéns! Seu sistema CrediVision SEM BANCO DE DADOS está pronto!${NC}"
