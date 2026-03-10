#!/bin/bash

# Script para atualizar o sistema CrediVision após correções de código

echo "=========================================="
echo "Atualizando Sistema CrediVision"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash atualizar.sh"
    exit 1
fi

# Obter diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "PASSO 1: Parando serviços..."
systemctl stop credivision-kiosk.service
systemctl stop credivision-app.service
sleep 2

echo ""
echo "PASSO 2: Parando container Docker..."
docker compose down
sleep 2

echo ""
echo "PASSO 3: Removendo imagem antiga..."
docker rmi credivision-app 2>/dev/null || true

echo ""
echo "PASSO 4: Construindo nova imagem Docker..."
docker build -f Dockerfile.production -t credivision-app .

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha ao construir imagem Docker"
    exit 1
fi

echo ""
echo "PASSO 5: Iniciando serviços..."
systemctl start credivision-app.service
sleep 5

echo ""
echo "PASSO 6: Verificando status da aplicação..."
systemctl status credivision-app.service --no-pager -l

echo ""
echo "PASSO 7: Verificando container Docker..."
docker ps | grep credivision-app

echo ""
echo "PASSO 8: Aguardando aplicação ficar pronta..."
sleep 10

echo ""
echo "PASSO 9: Testando API..."
curl -s http://localhost:5000/api/config > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ API respondendo corretamente"
else
    echo "✗ API não está respondendo"
    echo "Verifique os logs: docker logs credivision-app"
fi

echo ""
echo "PASSO 10: Iniciando kiosk..."
systemctl start credivision-kiosk.service
sleep 2

echo ""
echo "=========================================="
echo "Atualização Concluída!"
echo "=========================================="
echo ""
echo "Comandos úteis:"
echo "  Ver logs da aplicação: docker logs credivision-app"
echo "  Ver logs do kiosk: sudo journalctl -u credivision-kiosk.service -f"
echo "  Status dos serviços: sudo bash manage.sh status"
echo "  Acessar admin: http://localhost:5000"
echo ""
