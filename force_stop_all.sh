#!/bin/bash

# Script para parada forçada de todos os serviços CrediVision e Docker

echo "=========================================="
echo "Force Stop All - CrediVision & Docker"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERRO: Execute este script com sudo${NC}"
    echo "Uso: sudo bash force_stop_all.sh"
    exit 1
fi

# Get current user
CURRENT_USER=${SUDO_USER:-$USER}
PROJECT_DIR="/home/$CURRENT_USER/Documentos/CrediVision"

echo "Usuário: $CURRENT_USER"
echo "Diretório: $PROJECT_DIR"
echo ""

log_step "PASSO 1: Parando serviços systemd..."

# Parar todos os serviços CrediVision
echo "Parando credivision-kiosk.service..."
systemctl stop credivision-kiosk.service 2>/dev/null || true
systemctl disable credivision-kiosk.service 2>/dev/null || true

echo "Parando credivision-app.service..."
systemctl stop credivision-app.service 2>/dev/null || true
systemctl disable credivision-app.service 2>/dev/null || true

echo "Parando credivision-backup.service..."
systemctl stop credivision-backup.service 2>/dev/null || true
systemctl disable credivision-backup.service 2>/dev/null || true

echo "Parando credivision-backup.timer..."
systemctl stop credivision-backup.timer 2>/dev/null || true
systemctl disable credivision-backup.timer 2>/dev/null || true

log_step "PASSO 2: Matando processos relacionados..."

# Matar processos Firefox
echo "Matando processos Firefox..."
pkill -f "firefox" 2>/dev/null || true
pkill -f "simple_kiosk.sh" 2>/dev/null || true
pkill -f "start_kiosk.sh" 2>/dev/null || true
pkill -f "rotate_tabs.py" 2>/dev/null || true

# Matar processos Python relacionados
echo "Matando processos Python..."
pkill -f "app_no_db.py" 2>/dev/null || true
pkill -f "credivision" 2>/dev/null || true

# Matar processos Docker Compose
echo "Matando processos Docker Compose..."
pkill -f "docker-compose" 2>/dev/null || true

log_step "PASSO 3: Parando containers Docker..."

# Parar containers do CrediVision
cd "$PROJECT_DIR" 2>/dev/null || cd /tmp
if [ -f "docker-compose.production.yml" ]; then
    echo "Parando Docker Compose..."
    docker-compose -f docker-compose.production.yml down --remove-orphans 2>/dev/null || true
fi

# Parar todos os containers
echo "Parando todos os containers..."
docker stop $(docker ps -q) 2>/dev/null || true

log_step "PASSO 4: Removendo containers Docker..."

# Remover containers do CrediVision
echo "Removendo containers credivision-app..."
docker rm -f credivision-app 2>/dev/null || true

# Remover todos os containers
echo "Removendo todos os containers..."
docker rm -f $(docker ps -aq) 2>/dev/null || true

log_step "PASSO 5: Removendo imagens Docker..."

# Remover imagens do CrediVision
echo "Removendo imagens credivision-app..."
docker rmi -f credivision-app 2>/dev/null || true
docker rmi -f $(docker images -q credivision-app) 2>/dev/null || true

# Remover todas as imagens (opcional - comentado para segurança)
# echo "Removendo todas as imagens..."
# docker rmi -f $(docker images -q) 2>/dev/null || true

log_step "PASSO 6: Limpando cache Docker..."

# Limpar cache do Docker completamente
echo "Limpando builder cache..."
docker builder prune -a -f

echo "Limpando system cache..."
docker system prune -a -f --volumes

log_step "PASSO 7: Limpando arquivos temporários..."

# Limpar arquivos temporários
echo "Limpando arquivos temporários..."
rm -rf /tmp/credivision_* 2>/dev/null || true
rm -rf /tmp/credivision* 2>/dev/null || true

# Limpar arquivos de lock
echo "Limpando arquivos de lock..."
rm -f /var/lib/docker/tmp/*.id 2>/dev/null || true

log_step "PASSO 8: Resetando Docker..."

# Parar serviço Docker
echo "Parando serviço Docker..."
systemctl stop docker 2>/dev/null || true

# Limpar diretórios do Docker
echo "Limpando diretórios do Docker..."
rm -rf /var/lib/docker/* 2>/dev/null || true

# Iniciar Docker novamente
echo "Iniciando Docker novamente..."
systemctl start docker
systemctl enable docker

# Aguardar Docker iniciar
echo "Aguardando Docker iniciar..."
sleep 5

log_step "PASSO 9: Verificando limpeza..."

echo ""
echo "Verificando status final..."

# Verificar serviços
echo "Serviços systemd:"
systemctl list-units | grep credivision || echo "✓ Nenhum serviço credivision encontrado"

# Verificar containers
echo "Containers Docker:"
docker ps -a | grep credivision || echo "✓ Nenhum container credivision encontrado"

# Verificar imagens
echo "Imagens Docker:"
docker images | grep credivision || echo "✓ Nenhuma imagem credivision encontrada"

# Verificar processos
echo "Processos Firefox:"
ps aux | grep firefox | grep -v grep || echo "✓ Nenhum processo Firefox encontrado"

echo "Processos CrediVision:"
ps aux | grep credivision | grep -v grep || echo "✓ Nenhum processo credivision encontrado"

log_step "PASSO 10: Status do Docker..."

# Verificar status do Docker
echo ""
echo "Status Docker:"
docker --version
docker info | head -5

echo ""
echo "=========================================="
echo "LIMPEZA CONCLUÍDA!"
echo "=========================================="
echo ""
echo "Tudo foi parado e removido:"
echo "✓ Serviços systemd parados e desabilitados"
echo "✓ Containers Docker removidos"
echo "✓ Imagens Docker removidas"
echo "✓ Cache Docker limpo"
echo "✓ Processos finalizados"
echo "✓ Arquivos temporários limpos"
echo "✓ Docker resetado"
echo ""
echo "O sistema está pronto para reinstalação limpa."
echo ""
echo "Para reinstalar:"
echo "  cd $PROJECT_DIR"
echo "  sudo bash install_simple_kiosk.sh"
echo ""
echo "Para testar apenas a aplicação:"
echo "  cd $PROJECT_DIR"
echo "  docker build --no-cache -f Dockerfile.production -t credivision-app ."
echo "  docker-compose -f docker-compose.production.yml up -d"
echo ""
echo "Para testar o kiosk manualmente:"
echo "  sudo -u $CURRENT_USER $PROJECT_DIR/simple_kiosk.sh debug"
echo ""
