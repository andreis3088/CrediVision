#!/bin/bash
# SOLUÇÃO RÁPIDA - Execute este comando no Ubuntu

echo "=== CORREÇÃO RÁPIDA CrediVision ==="
cd /home/informa/Documentos/CrediVision

# Corrigir arquivos diretamente
echo "Corrigindo base.html..."
sed -i "s/logs_view/logs_list/g" templates/base.html

echo "Corrigindo dashboard.html..."
sed -i "s/logs_view/logs_list/g" templates/dashboard.html

# Verificar correções
echo ""
echo "Verificando correções..."
if grep -q "logs_view" templates/base.html; then
    echo "ERRO: base.html ainda tem logs_view"
else
    echo "✓ base.html corrigido"
fi

if grep -q "logs_view" templates/dashboard.html; then
    echo "ERRO: dashboard.html ainda tem logs_view"
else
    echo "✓ dashboard.html corrigido"
fi

# Parar serviços
echo ""
echo "Parando serviços..."
sudo systemctl stop credivision-kiosk.service
sudo systemctl stop credivision-app.service

# Remover container e imagem
echo "Removendo container e imagem antiga..."
docker compose down
docker rm -f credivision-app 2>/dev/null
docker rmi -f credivision-app 2>/dev/null

# Rebuild sem cache
echo ""
echo "Reconstruindo imagem (pode demorar 1-2 minutos)..."
docker build --no-cache -f Dockerfile.production -t credivision-app .

# Iniciar
echo ""
echo "Iniciando container..."
docker compose up -d
sleep 10

# Testar
echo ""
echo "Testando API..."
curl -s http://localhost:5000/api/config > /dev/null && echo "✓ API OK" || echo "✗ API falhou"

# Iniciar serviços
echo ""
echo "Iniciando serviços..."
sudo systemctl start credivision-app.service
sleep 5
sudo systemctl start credivision-kiosk.service

echo ""
echo "=== CONCLUÍDO ==="
echo "Acesse: http://$(hostname -I | awk '{print $1}'):5000"
