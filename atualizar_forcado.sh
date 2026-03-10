#!/bin/bash

# Script para atualização FORÇADA do sistema CrediVision
# Remove completamente cache e imagens antigas

echo "=========================================="
echo "Atualização FORÇADA - CrediVision"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash atualizar_forcado.sh"
    exit 1
fi

# Obter diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Diretório do projeto: $SCRIPT_DIR"
echo ""

echo "PASSO 1: Parando todos os serviços..."
systemctl stop credivision-kiosk.service
systemctl stop credivision-app.service
sleep 3

echo ""
echo "PASSO 2: Removendo containers e imagens antigas..."
docker compose down --remove-orphans
docker stop credivision-app 2>/dev/null || true
docker rm credivision-app 2>/dev/null || true
docker rmi credivision-app 2>/dev/null || true
docker rmi $(docker images -q credivision-app) 2>/dev/null || true

echo ""
echo "PASSO 3: Limpando cache do Docker..."
docker builder prune -f

echo ""
echo "PASSO 4: Verificando arquivos necessários..."
if [ ! -f "app_no_db.py" ]; then
    echo "ERRO: app_no_db.py não encontrado!"
    exit 1
fi

if [ ! -f "Dockerfile.production" ]; then
    echo "ERRO: Dockerfile.production não encontrado!"
    exit 1
fi

if [ ! -d "templates" ]; then
    echo "ERRO: Diretório templates/ não encontrado!"
    exit 1
fi

echo "✓ Todos os arquivos necessários encontrados"

echo ""
echo "PASSO 5: Construindo nova imagem (SEM CACHE)..."
docker build --no-cache -f Dockerfile.production -t credivision-app .

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha ao construir imagem Docker"
    echo "Verifique os logs acima para detalhes"
    exit 1
fi

echo ""
echo "PASSO 6: Verificando imagem criada..."
docker images | grep credivision-app

echo ""
echo "PASSO 7: Criando e iniciando container..."
docker compose up -d

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha ao iniciar container"
    exit 1
fi

echo ""
echo "PASSO 8: Aguardando container inicializar..."
sleep 10

echo ""
echo "PASSO 9: Verificando status do container..."
docker ps | grep credivision-app

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Container não está rodando!"
    echo "Logs do container:"
    docker logs credivision-app
    exit 1
fi

echo ""
echo "PASSO 10: Testando API..."
for i in {1..5}; do
    curl -s http://localhost:5000/api/config > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ API respondendo corretamente"
        break
    fi
    if [ $i -eq 5 ]; then
        echo "✗ API não está respondendo após 5 tentativas"
        echo "Logs do container:"
        docker logs credivision-app
        exit 1
    fi
    echo "Tentativa $i/5 - Aguardando API..."
    sleep 3
done

echo ""
echo "PASSO 11: Iniciando serviço da aplicação..."
systemctl start credivision-app.service
sleep 3

echo ""
echo "PASSO 12: Verificando serviço da aplicação..."
systemctl status credivision-app.service --no-pager -l | head -20

echo ""
echo "PASSO 13: Iniciando kiosk..."
systemctl start credivision-kiosk.service
sleep 3

echo ""
echo "PASSO 14: Verificando serviço do kiosk..."
systemctl status credivision-kiosk.service --no-pager -l | head -20

echo ""
echo "=========================================="
echo "Atualização FORÇADA Concluída!"
echo "=========================================="
echo ""
echo "Verificações finais:"
echo ""

# Container rodando?
if docker ps | grep -q credivision-app; then
    echo "✓ Container Docker rodando"
else
    echo "✗ Container Docker NÃO está rodando"
fi

# Serviço app ativo?
if systemctl is-active --quiet credivision-app.service; then
    echo "✓ Serviço credivision-app ativo"
else
    echo "✗ Serviço credivision-app NÃO está ativo"
fi

# Serviço kiosk ativo?
if systemctl is-active --quiet credivision-kiosk.service; then
    echo "✓ Serviço credivision-kiosk ativo"
else
    echo "✗ Serviço credivision-kiosk NÃO está ativo"
fi

# API respondendo?
if curl -s http://localhost:5000/api/config > /dev/null 2>&1; then
    echo "✓ API respondendo"
else
    echo "✗ API NÃO está respondendo"
fi

echo ""
echo "Comandos úteis:"
echo "  Ver logs: docker logs credivision-app"
echo "  Ver logs kiosk: sudo journalctl -u credivision-kiosk.service -f"
echo "  Status: sudo bash manage.sh status"
echo "  Acessar: http://localhost:5000"
echo ""
echo "Teste acessando: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
