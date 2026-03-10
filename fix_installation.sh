#!/bin/bash

# Script de Correção Rápida - CrediVision
# Uso: sudo bash fix_installation.sh

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "🔧 CORREÇÃO RÁPIDA - CREDIVISION"
echo "==============================="

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Execute como root: sudo bash fix_installation.sh"
   exit 1
fi

# Configurar variáveis
PROJECT_DIR="$(pwd)"
SERVICE_USER="$SUDO_USER"
APP_PORT="5000"

echo ""
print_step "1. Parando serviços existentes..."

# Parar tudo
systemctl stop credvision-app.service 2>/dev/null || true
systemctl stop credvision-kiosk.service 2>/dev/null || true
systemctl stop credvision-boot.service 2>/dev/null || true

# Parar containers Docker
docker stop credvision-app 2>/dev/null || true
docker rm credvision-app 2>/dev/null || true

print_status "Serviços parados"

echo ""
print_step "2. Verificando e corrigindo arquivos..."

# Verificar arquivos essenciais
if [ ! -f "docker-compose.yml" ]; then
    print_warning "docker-compose.yml não encontrado, criando..."
    cat > docker-compose.yml << EOF
version: "3.9"

services:
  credvision-app:
    build: .
    container_name: credvision-app
    volumes:
      - /home/$SERVICE_USER/Documents/kiosk-data:/data:rw
      - /home/$SERVICE_USER/Documents/kiosk-media:/media:rw
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
fi

if [ ! -f "Dockerfile" ]; then
    print_warning "Dockerfile não encontrado, criando..."
    cat > Dockerfile << EOF
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
fi

if [ ! -f ".env" ]; then
    print_warning ".env não encontrado, criando..."
    SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || echo "default_key_$(date +%s)")
    cat > .env << EOF
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
ADMIN_URL=http://localhost:$APP_PORT
KIOSK_MODE=app-only
CONFIG_REFRESH=300
EOF
fi

print_status "Arquivos verificados/corrigidos"

echo ""
print_step "3. Criando diretórios..."

# Criar diretórios
mkdir -p "/home/$SERVICE_USER/Documents/kiosk-data"
mkdir -p "/home/$SERVICE_USER/Documents/kiosk-media"
mkdir -p "/home/$SERVICE_USER/Documents/kiosk-media/imagens"
mkdir -p "/home/$SERVICE_USER/Documents/kiosk-media/videos"
mkdir -p "/home/$SERVICE_USER/Documents/kiosk-media/outros"

# Criar arquivos JSON vazios se não existirem
if [ ! -f "/home/$SERVICE_USER/Documents/kiosk-data/tabs.json" ]; then
    echo "[]" > "/home/$SERVICE_USER/Documents/kiosk-data/tabs.json"
fi

if [ ! -f "/home/$SERVICE_USER/Documents/kiosk-data/users.json" ]; then
    echo "[]" > "/home/$SERVICE_USER/Documents/kiosk-data/users.json"
fi

if [ ! -f "/home/$SERVICE_USER/Documents/kiosk-data/logs.json" ]; then
    echo "[]" > "/home/$SERVICE_USER/Documents/kiosk-data/logs.json"
fi

# Corrigir permissões
chown -R $SERVICE_USER:$SERVICE_USER "/home/$SERVICE_USER/Documents/kiosk-"*
chmod 755 "/home/$SERVICE_USER/Documents/kiosk-"*

print_status "Diretórios criados e permissões corrigidas"

echo ""
print_step "4. Configurando ambiente Python..."

# Criar/verificar ambiente virtual
if [ ! -d "venv" ]; then
    print_status "Criando ambiente virtual..."
    sudo -u $SERVICE_USER python3 -m venv venv
fi

# Instalar dependências
print_status "Instalando dependências Python..."
sudo -u $SERVICE_USER bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

print_status "Ambiente Python configurado"

echo ""
print_step "5. Iniciando Docker..."

# Verificar Docker
if ! systemctl is-active docker >/dev/null 2>&1; then
    print_status "Iniciando Docker..."
    systemctl start docker
    sleep 5
fi

print_status "Docker ativo"

echo ""
print_step "6. Build e teste do Docker..."

# Build Docker
print_status "Fazendo build da imagem Docker..."
sudo -u $SERVICE_USER docker build -t credvision-app . || {
    print_error "Build Docker falhou"
    echo "Verificando logs de build..."
    sudo -u $SERVICE_USER docker build -t credvision-app . 2>&1 | tail -20
    exit 1
}

print_status "Build concluído"

# Testar container
print_status "Testando container..."
docker run -d --name credvision-app-test \
    -v "/home/$SERVICE_USER/Documents/kiosk-data:/data:rw" \
    -v "/home/$SERVICE_USER/Documents/kiosk-media:/media:rw" \
    -p "$APP_PORT:5000" \
    --restart unless-stopped \
    credvision-app

sleep 15

# Testar API
if curl -s --connect-timeout 10 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    print_status "✅ Container funcionando!"
    
    # Parar container de teste
    docker stop credvision-app-test
    docker rm credvision-app-test
else
    print_error "❌ Container não responde"
    echo "Logs do container:"
    docker logs credvision-app-test
    docker stop credvision-app-test
    docker rm credvision-app-test
    exit 1
fi

echo ""
print_step "7. Iniciando serviços systemd..."

# Recarregar systemd
systemctl daemon-reload

# Iniciar serviço principal
print_status "Iniciando credvision-app.service..."
systemctl start credvision-app.service

# Aguardar
sleep 20

# Verificar status
if systemctl is-active credvision-app.service >/dev/null 2>&1; then
    print_status "✅ credvision-app.service ativo"
else
    print_error "❌ credvision-app.service não iniciou"
    echo "Logs do serviço:"
    journalctl -u credvision-app.service -n 20
fi

# Testar API via systemd
if curl -s --connect-timeout 10 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    print_status "✅ API funcionando via systemd!"
else
    print_error "❌ API não responde via systemd"
fi

echo ""
print_step "8. Criando usuário admin..."

# Criar usuário admin
python3 << EOF
import json
import hashlib
from datetime import datetime

# Configurações
username = "admin"
password = "admin123"
users_file = "/home/$SERVICE_USER/Documents/kiosk-data/users.json"

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

# Corrigir permissões
chown $SERVICE_USER:$SERVICE_USER "/home/$SERVICE_USER/Documents/kiosk-data/users.json"
chmod 644 "/home/$SERVICE_USER/Documents/kiosk-data/users.json"

print_status "Usuário admin configurado"

echo ""
print_step "9. Teste final..."

# Teste final da API
if curl -s --connect-timeout 10 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    print_status "✅ Sistema funcionando!"
    
    # Obter informações
    ABAS_COUNT=$(curl -s http://localhost:$APP_PORT/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))" 2>/dev/null || echo "0")
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "🎉 CORREÇÃO CONCLUÍDA COM SUCESSO!"
    echo ""
    echo "📍 ACESSO AO SISTEMA:"
    echo "   🌐 Admin: http://$IP_ADDRESS:$APP_PORT"
    echo "   📺 Display: http://$IP_ADDRESS:$APP_PORT/display"
    echo ""
    echo "👤 CREDENCIAIS:"
    echo "   👤 Usuário: admin"
    echo "   🔑 Senha: admin123"
    echo ""
    echo "📊 STATUS:"
    echo "   ✅ Docker: Ativo"
    echo "   ✅ Container: Rodando"
    echo "   ✅ API: Respondendo"
    echo "   ✅ Abas: $ABAS_COUNT configuradas"
    echo ""
    echo "🔧 PARA INICIAR O KIOSK:"
    echo "   sudo systemctl start credvision-kiosk.service"
    echo ""
    echo "📋 COMANDOS ÚTEIS:"
    echo "   📊 Status: sudo systemctl status credvision-app"
    echo "   📋 Logs: sudo journalctl -u credvision-app -f"
    echo "   🔄 Restart: sudo systemctl restart credvision-app"
    echo "   🐳 Docker: docker ps && docker logs credvision-app"
    
else
    print_error "❌ Sistema ainda não funcionando"
    echo ""
    echo "🔧 VERIFICAÇÃO MANUAL:"
    echo "1. Verifique se o Docker está rodando: docker ps"
    echo "2. Verifique logs do container: docker logs credvision-app"
    echo "3. Verifique logs do serviço: journalctl -u credvision-app -f"
    echo "4. Teste API manual: curl http://localhost:$APP_PORT/api/config"
    echo ""
    echo "🔧 EXECUÇÃO MANUAL:"
    echo "cd $PROJECT_DIR"
    echo "sudo -u $SERVICE_USER docker compose up -d"
fi

echo ""
echo "🎊 Processo de correção concluído!"
