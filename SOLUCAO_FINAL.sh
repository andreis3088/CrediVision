#!/bin/bash

echo "=== SOLUÇÃO DEFINITIVA - CrediVision ==="
cd /home/informa/Documentos/CrediVision

# 1. Verificar arquivos atuais
echo "Verificando arquivos atuais..."
echo "base.html:"
grep -n "logs_" templates/base.html | head -3
echo ""
echo "dashboard.html:"
grep -n "logs_" templates/dashboard.html | head -3
echo ""

# 2. Corrigir arquivos FORÇADAMENTE
echo "Corrigindo arquivos..."
cp templates/base.html templates/base.html.backup
cp templates/dashboard.html templates/dashboard.html.backup

# Substituir logs_view por logs_list
sed -i 's/logs_view/logs_list/g' templates/base.html
sed -i 's/logs_view/logs_list/g' templates/dashboard.html

# Verificar se correção funcionou
echo ""
echo "Verificando correções..."
if grep -q "logs_view" templates/base.html; then
    echo "ERRO: base.html ainda tem logs_view"
    echo "Conteúdo problemático:"
    grep -n "logs_view" templates/base.html
else
    echo "✓ base.html corrigido"
fi

if grep -q "logs_view" templates/dashboard.html; then
    echo "ERRO: dashboard.html ainda tem logs_view"
    echo "Conteúdo problemático:"
    grep -n "logs_view" templates/dashboard.html
else
    echo "✓ dashboard.html corrigido"
fi

# 3. Parar tudo completamente
echo ""
echo "Parando todos os serviços..."
sudo systemctl stop credivision-kiosk.service
sudo systemctl stop credivision-app.service
docker compose down
docker stop $(docker ps -q) 2>/dev/null || true

# 4. Remover TUDO relacionado ao CrediVision
echo ""
echo "Removendo containers e imagens..."
docker rm -f credivision-app 2>/dev/null || true
docker rmi -f credivision-app 2>/dev/null || true
docker rmi $(docker images -q credivision-app) 2>/dev/null || true

# 5. Limpar cache do Docker completamente
echo "Limpando cache do Docker..."
docker builder prune -a -f
docker system prune -f

# 6. Reconstruir imagem SEM CACHE
echo ""
echo "Reconstruindo imagem (sem cache)..."
docker build --no-cache --pull -f Dockerfile.production -t credivision-app .

# 7. Iniciar container
echo ""
echo "Iniciando container..."
docker compose up -d

# 8. Aguardar e testar
echo ""
echo "Aguardando inicialização..."
sleep 15

# Testar API
echo "Testando API..."
for i in {1..10}; do
    if curl -s http://localhost:5000/api/config > /dev/null 2>&1; then
        echo "✓ API respondendo"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "✗ API não respondeu após 10 tentativas"
        echo "Logs do container:"
        docker logs credivision-app
        exit 1
    fi
    echo "Tentativa $i/10..."
    sleep 2
done

# 9. Verificar conteúdo DENTRO do container
echo ""
echo "Verificando arquivos DENTRO do container..."
echo "base.html no container:"
docker exec credivision-app grep -n "logs_" /app/templates/base.html | head -3
echo ""
echo "dashboard.html no container:"
docker exec credivision-app grep -n "logs_" /app/templates/dashboard.html | head -3

# 10. Iniciar serviços systemd
echo ""
echo "Iniciando serviços systemd..."
sudo systemctl start credivision-app.service
sleep 5
sudo systemctl start credivision-kiosk.service

# 11. Verificação final
echo ""
echo "=== VERIFICAÇÃO FINAL ==="
echo ""

# Verificar se logs_view ainda existe no container
if docker exec credivision-app grep -q "logs_view" /app/templates/base.html; then
    echo "❌ ERRO: Container ainda tem logs_view!"
    echo "O problema persistirá!"
else
    echo "✅ Container não tem mais logs_view"
fi

if docker exec credivision-app grep -q "logs_view" /app/templates/dashboard.html; then
    echo "❌ ERRO: Container ainda tem logs_view!"
    echo "O problema persistirá!"
else
    echo "✅ Container não tem mais logs_view"
fi

# Status dos serviços
echo ""
echo "Status dos serviços:"
systemctl is-active credivision-app.service && echo "✓ App service ativo" || echo "❌ App service inativo"
systemctl is-active credivision-kiosk.service && echo "✓ Kiosk service ativo" || echo "❌ Kiosk service inativo"
docker ps | grep -q credivision-app && echo "✓ Container rodando" || echo "❌ Container não rodando"

echo ""
echo "=== CONCLUÍDO ==="
echo "Acesse: http://$(hostname -I | awk '{print $1}'):5000"
echo "Se ainda der erro, o problema está nos arquivos originais!"
echo ""
echo "Comandos úteis:"
echo "  Ver logs: docker logs credivision-app"
echo "  Ver arquivos no container: docker exec -it credivision-app /bin/bash"
echo ""
