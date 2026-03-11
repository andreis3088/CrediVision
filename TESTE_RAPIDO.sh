#!/bin/bash

echo "=========================================="
echo "TESTE RÁPIDO - CREDIVISION"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash TESTE_RAPIDO.sh"
    exit 1
fi

echo "1. Verificando serviços..."
echo ""

# Verificar serviço Flask
echo "Serviço Flask:"
systemctl status credivision-app.service --no-pager
echo ""

# Verificar se está rodando
if pgrep -f "python.*app.py" > /dev/null; then
    echo "✓ Processo Python Flask rodando"
else
    echo "✗ Processo Python Flask NÃO está rodando"
    echo "Tentando iniciar..."
    systemctl start credivision-app.service
    sleep 3
fi

echo ""
echo "2. Testando acesso à aplicação..."
echo ""

# Testar se a aplicação responde
if curl -s http://localhost:5000 > /dev/null; then
    echo "✓ Aplicação Flask respondendo"
    echo "URL: http://localhost:5000"
else
    echo "✗ Aplicação Flask NÃO respondendo"
    echo "Verificando logs..."
    journalctl -u credivision-app.service -n 10 --no-pager
fi

echo ""
echo "3. Verificando kiosk..."
echo ""

# Verificar serviço kiosk
echo "Serviço Kiosk:"
systemctl status credivision-kiosk.service --no-pager
echo ""

# Verificar se Firefox está rodando
if pgrep -f firefox > /dev/null; then
    echo "✓ Firefox está rodando"
    echo "Processos: $(pgrep -f firefox | wc -l)"
else
    echo "✗ Firefox NÃO está rodando"
fi

echo ""
echo "4. Verificando arquivos..."
echo ""

# Verificar arquivos principais
FILES=(
    "/home/informa/Documents/CrediVision/app.py"
    "/home/informa/Documents/kiosk-data/tabs.json"
    "/home/informa/Documents/kiosk-media"
)

for file in "${FILES[@]}"; do
    if [ -e "$file" ]; then
        echo "✓ $file existe"
        if [ -d "$file" ]; then
            echo "   Conteúdo: $(ls -la "$file" | wc -l) itens"
        else
            echo "   Tamanho: $(stat -c%s "$file") bytes"
        fi
    else
        echo "✗ $file NÃO existe"
    fi
done

echo ""
echo "5. Testando kiosk manualmente..."
echo ""

# Testar kiosk manualmente por 10 segundos
echo "Iniciando kiosk manualmente por 10 segundos..."
sudo -u informa timeout 10s bash /home/informa/Documents/CrediVision/kiosk.sh &
KIOSK_PID=$!

sleep 12

# Verificar resultado
if pgrep -f firefox > /dev/null; then
    echo "✓ Kiosk manual funcionou!"
    echo "Parando..."
    pkill -f firefox
else
    echo "✗ Kiosk manual NÃO funcionou"
fi

echo ""
echo "6. Verificando logs de erros..."
echo ""

# Verificar logs recentes
echo "Logs recentes do kiosk:"
journalctl -u credivision-kiosk.service -n 5 --no-pager

echo ""
echo "Logs recentes do app:"
journalctl -u credivision-app.service -n 5 --no-pager

echo ""
echo "=========================================="
echo "TESTE CONCLUÍDO"
echo "=========================================="
echo ""
echo "Se encontrar problemas:"
echo "1. Reiniciar serviços: sudo systemctl restart credivision-app.service credivision-kiosk.service"
echo "2. Verificar logs: sudo journalctl -u credivision-kiosk.service -f"
echo "3. Testar manualmente: sudo -u informa bash /home/informa/Documents/CrediVision/kiosk.sh"
echo ""
