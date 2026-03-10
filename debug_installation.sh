#!/bin/bash

# Script de Diagnóstico Rápido - CrediVision
# Uso: sudo bash debug_installation.sh

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

echo "🔍 DIAGNÓSTICO RÁPIDO - CREDIVISION"
echo "=================================="

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Execute como root: sudo bash debug_installation.sh"
   exit 1
fi

# Configurar variáveis
PROJECT_DIR="$(pwd)"
SERVICE_USER="$SUDO_USER"
APP_PORT="5000"

echo ""
print_step "1. Verificando ambiente básico..."

# Verificar Python
if command -v python3 &> /dev/null; then
    echo "   ✅ Python3: $(python3 --version)"
else
    echo "   ❌ Python3 não encontrado"
fi

# Verificar Docker
if command -v docker &> /dev/null; then
    echo "   ✅ Docker: $(docker --version)"
else
    echo "   ❌ Docker não encontrado"
fi

# Verificar Docker Compose
if command -v docker compose &> /dev/null; then
    echo "   ✅ Docker Compose: $(docker compose version)"
else
    echo "   ❌ Docker Compose não encontrado"
fi

echo ""
print_step "2. Verificando arquivos do projeto..."

# Verificar arquivos essenciais
files=("app_no_db.py" "app.py" "requirements.txt" "docker-compose.yml" "Dockerfile")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file encontrado"
    else
        echo "   ❌ $file não encontrado"
    fi
done

echo ""
print_step "3. Verificando diretórios..."

# Verificar diretórios
dirs=("/home/$SERVICE_USER/Documents/kiosk-data" "/home/$SERVICE_USER/Documents/kiosk-media")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "   ✅ $dir existe"
        ls -la "$dir" | head -3
    else
        echo "   ❌ $dir não existe"
    fi
done

echo ""
print_step "4. Verificando serviços systemd..."

services=("credvision-app.service" "credvision-kiosk.service" "credvision-boot.service")
for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "   ✅ $service existe"
        echo "      Status: $(systemctl is-active $service 2>/dev/null || echo 'inativo')"
        echo "      Habilitado: $(systemctl is-enabled $service 2>/dev/null || echo 'desabilitado')"
    else
        echo "   ❌ $service não existe"
    fi
done

echo ""
print_step "5. Verificando Docker..."

# Verificar se Docker está rodando
if systemctl is-active docker >/dev/null 2>&1; then
    echo "   ✅ Docker está ativo"
else
    echo "   ❌ Docker não está ativo"
    echo "   🔧 Tentando iniciar Docker..."
    systemctl start docker
    sleep 5
fi

# Verificar containers
echo "   📦 Containers Docker:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep credvision || echo "   ❌ Nenhum container credvision encontrado"

echo ""
print_step "6. Verificando portas..."

# Verificar porta 5000
if netstat -tlnp 2>/dev/null | grep -q ":$APP_PORT "; then
    echo "   ✅ Porta $APP_PORT está em uso"
    netstat -tlnp 2>/dev/null | grep ":$APP_PORT "
else
    echo "   ❌ Porta $APP_PORT não está em uso"
fi

echo ""
print_step "7. Testando conectividade..."

# Testar API local
if curl -s --connect-timeout 5 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    echo "   ✅ API respondendo em localhost:$APP_PORT"
else
    echo "   ❌ API não respondendo em localhost:$APP_PORT"
fi

echo ""
print_step "8. Verificando logs recentes..."

# Logs do systemd
echo "   📋 Logs recentes do credvision-app:"
journalctl -u credvision-app --no-pager -n 10 2>/dev/null | tail -5 || echo "   ❌ Sem logs disponíveis"

echo ""
print_step "9. Tentativas de correção automática..."

# Correção 1: Verificar permissões
echo "   🔧 Verificando permissões..."
chown -R $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/Documents/kiosk-* 2>/dev/null || true
chmod 755 /home/$SERVICE_USER/Documents/kiosk-* 2>/dev/null || true

# Correção 2: Verificar ambiente Python
echo "   🔧 Verificando ambiente Python..."
if [ -d "$PROJECT_DIR/venv" ]; then
    echo "   ✅ Ambiente virtual existe"
else
    echo "   🔧 Criando ambiente virtual..."
    sudo -u $SERVICE_USER python3 -m venv "$PROJECT_DIR/venv"
fi

# Correção 3: Instalar dependências
echo "   🔧 Instalando dependências..."
sudo -u $SERVICE_USER bash -c "cd $PROJECT_DIR && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt" || true

# Correção 4: Verificar .env
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "   🔧 Criando .env..."
    SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || echo "default_key_123")
    cat > "$PROJECT_DIR/.env" << EOF
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
ADMIN_URL=http://localhost:$APP_PORT
KIOSK_MODE=app-only
CONFIG_REFRESH=300
EOF
    chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/.env"
    chmod 600 "$PROJECT_DIR/.env"
fi

echo ""
print_step "10. Testando Docker manualmente..."

# Parar container existente
docker stop credvision-app 2>/dev/null || true
docker rm credvision-app 2>/dev/null || true

# Tentar build manual
echo "   🔧 Tentando build manual do Docker..."
cd "$PROJECT_DIR"
if sudo -u $SERVICE_USER docker build -t credvision-app . 2>/dev/null; then
    echo "   ✅ Build Docker bem-sucedido"
    
    # Tentar rodar container manualmente
    echo "   🔧 Tentando rodar container manualmente..."
    if sudo -u $SERVICE_USER docker run -d --name credvision-app-test \
        -v "/home/$SERVICE_USER/Documents/kiosk-data:/data:rw" \
        -v "/home/$SERVICE_USER/Documents/kiosk-media:/media:rw" \
        -p "$APP_PORT:5000" \
        --restart unless-stopped \
        credvision-app 2>/dev/null; then
        
        echo "   ✅ Container iniciado manualmente"
        sleep 10
        
        # Testar API
        if curl -s --connect-timeout 5 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
            echo "   🎉 API respondendo! Container funcional"
            
            # Parar container de teste
            docker stop credvision-app-test
            docker rm credvision-app-test
            
            echo ""
            print_step "11. Iniciando serviços systemd..."
            
            # Iniciar serviço principal
            echo "   🔧 Iniciando credvision-app.service..."
            systemctl start credvision-app.service
            sleep 15
            
            # Verificar status
            if systemctl is-active credvision-app.service >/dev/null 2>&1; then
                echo "   ✅ credvision-app.service ativo"
                
                # Testar API novamente
                if curl -s --connect-timeout 5 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
                    echo "   🎉 API funcionando via systemd!"
                else
                    echo "   ⚠️ API não responde via systemd"
                fi
            else
                echo "   ❌ credvision-app.service não iniciou"
            fi
        else
            echo "   ❌ Container iniciado mas API não responde"
            echo "   📋 Logs do container:"
            docker logs credvision-app-test
        fi
    else
        echo "   ❌ Falha ao rodar container"
    fi
else
    echo "   ❌ Build Docker falhou"
fi

echo ""
print_step "12. Resumo e recomendações..."

# Status final
echo ""
echo "📊 STATUS FINAL:"
echo "==============="

# Docker
if systemctl is-active docker >/dev/null 2>&1; then
    echo "✅ Docker: Ativo"
else
    echo "❌ Docker: Inativo"
fi

# Container
if docker ps | grep -q credvision-app; then
    echo "✅ Container: Rodando"
else
    echo "❌ Container: Parado"
fi

# API
if curl -s --connect-timeout 5 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    echo "✅ API: Respondendo"
else
    echo "❌ API: Não respondendo"
fi

# Serviços
if systemctl is-active credvision-app.service >/dev/null 2>&1; then
    echo "✅ Serviço App: Ativo"
else
    echo "❌ Serviço App: Inativo"
fi

echo ""
echo "🔧 PRÓXIMOS PASSOS:"
echo "=================="

if curl -s --connect-timeout 5 http://localhost:$APP_PORT/api/config >/dev/null 2>&1; then
    echo "✅ Sistema funcionando! Acesse:"
    echo "   🌐 Admin: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
    echo "   👤 Login: admin / admin123"
    echo ""
    echo "🔧 Para iniciar kiosk:"
    echo "   sudo systemctl start credvision-kiosk.service"
else
    echo "❌ Sistema não funcionando. Tente:"
    echo ""
    echo "🔧 Opção 1 - Reiniciar tudo:"
    echo "   sudo systemctl restart docker"
    echo "   sudo systemctl start credvision-app.service"
    echo ""
    echo "🔧 Opção 2 - Ver logs:"
    echo "   sudo journalctl -u credvision-app -f"
    echo "   docker logs credvision-app"
    echo ""
    echo "🔧 Opção 3 - Executar manualmente:"
    echo "   cd $PROJECT_DIR"
    echo "   sudo -u $SERVICE_USER docker compose up -d"
    echo ""
    echo "🔧 Opção 4 - Verificar arquivos:"
    echo "   ls -la /home/$SERVICE_USER/Documents/kiosk-data/"
    echo "   ls -la /home/$SERVICE_USER/Documents/kiosk-media/"
fi

echo ""
echo "📋 Comandos úteis:"
echo "=================="
echo "🔍 Diagnóstico completo: sudo $PROJECT_DIR/diagnose_kiosk.sh"
echo "📊 Status serviços: sudo systemctl status credvision-*"
echo "📋 Logs: sudo journalctl -u credvision-app -f"
echo "🐳 Docker: docker ps && docker logs credvision-app"
echo "🔄 Restart: sudo systemctl restart credvision-app"

echo ""
echo "🎉 Diagnóstico concluído!"
