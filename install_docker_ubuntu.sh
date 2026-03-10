#!/bin/bash

# Script de Instalação do CrediVision com Docker no Ubuntu
# Uso: sudo bash install_docker_ubuntu.sh

set -e

echo "🚀 Iniciando instalação do CrediVision no Ubuntu"
echo "================================================"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Atualizar sistema
print_header "Atualizando sistema..."
apt update && apt upgrade -y

# Instalar dependências básicas
print_header "Instalando dependências básicas..."
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
    lsb-release

# Instalar Docker
print_header "Instalando Docker..."

# Remover versões antigas
apt remove -y docker docker-engine docker.io containerd runc || true

# Adicionar repositório Docker oficial
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Adicionar usuário atual ao grupo docker
print_header "Configurando permissões Docker..."
usermod -aG docker $SUDO_USER || true

# Iniciar e habilitar Docker
systemctl start docker
systemctl enable docker

# Verificar instalação Docker
print_status "Verificando instalação Docker..."
docker --version
docker compose version

# Criar diretório do projeto
print_header "Criando diretório do projeto..."
PROJECT_DIR="/opt/credvision"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Baixar arquivos do projeto (assumindo que estão no mesmo diretório)
print_header "Configurando arquivos do projeto..."

# Copiar arquivos do diretório atual
if [ -f "/tmp/credvision_files.zip" ]; then
    print_status "Descompactando arquivos do projeto..."
    unzip -o /tmp/credvision_files.zip -d $PROJECT_DIR/
else
    print_warning "Arquivos do projeto não encontrados. Você precisará copiá-los manualmente para $PROJECT_DIR"
fi

# Criar diretório de mídia
print_header "Criando diretório de mídia..."
MEDIA_DIR="/home/$SUDO_USER/Documentos/kiosk-media"
mkdir -p $MEDIA_DIR
chown -R $SUDO_USER:$SUDO_USER $MEDIA_DIR
chmod 755 $MEDIA_DIR

print_status "Diretório de mídia criado: $MEDIA_DIR"

# Criar arquivo .env
print_header "Configurando variáveis de ambiente..."
cat > $PROJECT_DIR/.env << EOF
# Configurações do CrediVision
SECRET_KEY=$(openssl rand -hex 32)
ADMIN_PASSWORD=admin123
DB_PATH=/data/kiosk.db
CONFIG_PATH=/data/config.json
ADMIN_URL=http://localhost:5000
KIOSK_MODE=full
CONFIG_REFRESH=300
DISPLAY=:0
MEDIA_FOLDER=$MEDIA_DIR
EOF

# Definir permissões
chown -R $SUDO_USER:$SUDO_USER $PROJECT_DIR
chmod +x $PROJECT_DIR/*.sh || true

# Criar serviço systemd
print_header "Criando serviço systemd..."
cat > /etc/systemd/system/credvision.service << EOF
[Unit]
Description=CrediVision Kiosk System
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Habilitar serviço
systemctl daemon-reload
systemctl enable credvision.service

# Criar script de atualização
print_header "Criando script de atualização..."
cat > $PROJECT_DIR/update.sh << 'EOF'
#!/bin/bash
# Script de atualização do CrediVision

echo "🔄 Atualizando CrediVision..."

# Parar serviços
docker compose down

# Pull de novas imagens
docker compose pull

# Reiniciar serviços
docker compose up -d

echo "✅ CrediVision atualizado com sucesso!"
EOF

chmod +x $PROJECT_DIR/update.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/update.sh

# Criar script de backup
print_header "Criando script de backup..."
cat > $PROJECT_DIR/backup.sh << 'EOF'
#!/bin/bash
# Script de backup do CrediVision

BACKUP_DIR="/opt/credvision-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/credvision_backup_$DATE.tar.gz"

echo "💾 Criando backup do CrediVision..."

# Criar diretório de backup
mkdir -p $BACKUP_DIR

# Parar serviços temporariamente
docker compose down

# Criar backup
tar -czf $BACKUP_FILE \
    /opt/credvision \
    /home/*/Documentos/kiosk-media

# Reiniciar serviços
docker compose up -d

echo "✅ Backup criado: $BACKUP_FILE"
echo "📊 Tamanho do backup: $(du -h $BACKUP_FILE | cut -f1)"

# Manter apenas os últimos 7 backups
find $BACKUP_DIR -name "credvision_backup_*.tar.gz" -mtime +7 -delete
EOF

chmod +x $PROJECT_DIR/backup.sh
chown $SUDO_USER:$SUDO_USER $PROJECT_DIR/backup.sh

# Configurar firewall (se necessário)
print_header "Configurando firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow 5000/tcp
    ufw allow ssh
    print_status "Firewall configurado"
else
    print_warning "UFW não encontrado. Configure o firewall manualmente se necessário."
fi

# Instalar Firefox (para kiosk mode)
print_header "Instalando Firefox..."
apt install -y firefox

# Configurar autostart do Firefox kiosk (opcional)
print_header "Configurando Firefox Kiosk..."
cat > /etc/systemd/system/firefox-kiosk.service << EOF
[Unit]
Description=Firefox Kiosk Mode
After=graphical-session.target

[Service]
Type=simple
User=$SUDO_USER
Environment=DISPLAY=:0
ExecStart=/usr/bin/firefox --kiosk http://localhost:5000/display
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

systemctl daemon-reload
systemctl enable firefox-kiosk.service

# Resumo final
print_header "Instalação concluída!"
echo ""
echo -e "${GREEN}✅ CrediVision instalado com sucesso!${NC}"
echo ""
echo "📍 Diretórios importantes:"
echo "   - Projeto: $PROJECT_DIR"
echo "   - Mídia: $MEDIA_DIR"
echo ""
echo "🔧 Comandos úteis:"
echo "   - Iniciar: sudo systemctl start credvision"
echo "   - Parar: sudo systemctl stop credvision"
echo "   - Status: sudo systemctl status credvision"
echo "   - Logs: sudo journalctl -u credvision -f"
echo "   - Atualizar: $PROJECT_DIR/update.sh"
echo "   - Backup: $PROJECT_DIR/backup.sh"
echo ""
echo "🌐 Acesso ao sistema:"
echo "   - Admin: http://$(hostname -I | awk '{print $1}'):5000"
echo "   - Display: http://$(hostname -I | awk '{print $1}'):5000/display"
echo ""
echo "👤 Credenciais padrão:"
echo "   - Usuário: admin"
echo "   - Senha: admin123"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "   - Troque a senha padrão após primeiro acesso"
echo "   - Adicione seus arquivos de imagem/vídeo em: $MEDIA_DIR"
echo "   - Reinicie o sistema para aplicar todas as configurações"
echo ""
echo -e "${GREEN}🎉 Parabéns! Seu sistema CrediVision está pronto para usar!${NC}"

# Perguntar se quer reiniciar agora
echo ""
read -p "Deseja reiniciar o sistema agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_status "Reiniciando sistema..."
    reboot
fi
