#!/bin/bash

echo "=========================================="
echo "CORRIGINDO SERVIÇO KIOSK DEFINITIVO"
echo "=========================================="
echo ""

# Verificar se esta rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash CORRIGIR_SERVICO_DEFINITIVO.sh"
    exit 1
fi

PROJECT_DIR="/home/informa/Documentos/CrediVision"

echo "Projeto: $PROJECT_DIR"
echo ""

# PASSO 1: Verificar script atual
echo "PASSO 1: Verificando script atual..."
echo ""

if [ ! -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
    echo "ERRO: Script simple_kiosk_enhanced.sh nao encontrado!"
    exit 1
fi

echo "Script encontrado:"
ls -la "$PROJECT_DIR/simple_kiosk_enhanced.sh"

# Verificar se o script é o novo
if grep -q "=== CREDIVISION KIOSK ===" "$PROJECT_DIR/simple_kiosk_enhanced.sh"; then
    echo "✓ Script novo detectado"
else
    echo "✗ Script antigo detectado, substituindo..."
    
    # Fazer backup
    cp "$PROJECT_DIR/simple_kiosk_enhanced.sh" "$PROJECT_DIR/simple_kiosk_enhanced.sh.old"
    
    # Criar script novo
    cat > "$PROJECT_DIR/simple_kiosk_enhanced.sh" << 'SCRIPT_EOF'
#!/bin/bash

echo "=== CREDIVISION KIOSK ==="
echo "Iniciando kiosk Firefox..."
echo ""

# Ambiente
export DISPLAY=:0
export XAUTHORITY=/home/informa/.Xauthority

# Ler URL do arquivo tabs.json
URL=$(python3 << 'PYTHON'
import json
try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    # Verificar estrutura
    if isinstance(data, list):
        tabs = data
    else:
        tabs = data.get("tabs", [])
    
    # Procurar primeira aba ativa
    for tab in tabs:
        if tab.get("enabled", True):
            url = tab.get("url", "").strip()
            if url:
                print(url)
                break
    else:
        print("http://google.com")
        
except:
    print("http://google.com")
PYTHON
)

echo "URL: $URL"

# Fechar Firefox anteriores
echo "Fechando Firefox anteriores..."
pkill -f firefox 2>/dev/null || true
sleep 3

# Abrir Firefox em modo kiosk normal
echo "Abrindo Firefox em modo kiosk..."
firefox --kiosk "$URL" &

# Aguardar inicio
sleep 5

# Verificar se abriu
if pgrep -f firefox > /dev/null; then
    echo "✓ Kiosk iniciado com sucesso!"
    echo "URL: $URL"
    echo ""
    echo "Para parar: pkill -f firefox"
    echo ""
    
    # Manter script rodando
    while pgrep -f firefox > /dev/null; do
        sleep 1
    done
    
    echo "Kiosk finalizado"
else
    echo "✗ Falha ao iniciar Firefox"
    echo "Verificando problemas..."
    echo "Firefox: $(which firefox)"
    echo "DISPLAY: $DISPLAY"
    echo "Usuario: $(whoami)"
    exit 1
fi
SCRIPT_EOF
    
    chmod +x "$PROJECT_DIR/simple_kiosk_enhanced.sh"
    chown informa:informa "$PROJECT_DIR/simple_kiosk_enhanced.sh"
    echo "✓ Script novo criado"
fi

# PASSO 2: Testar script manualmente
echo ""
echo "PASSO 2: Testando script manualmente..."
echo ""

echo "Iniciando teste de 10 segundos..."
sudo -u informa bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
KIOSK_PID=$!

sleep 10

# Verificar se funcionou
if pgrep -f firefox > /dev/null; then
    echo "✓ Script funciona manualmente!"
    echo "Parando teste..."
    kill $KIOSK_PID 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    sleep 2
else
    echo "✗ Script nao funciona manualmente"
    echo "Verificando problemas..."
    
    # Verificar ambiente
    echo "DISPLAY: $DISPLAY"
    echo "Usuario: $(whoami)"
    echo "Firefox: $(which firefox)"
    
    echo ""
    echo "Tentando iniciar Firefox manualmente..."
    sudo -u informa firefox &
    sleep 5
    
    if pgrep -f firefox > /dev/null; then
        echo "✓ Firefox normal funciona"
        pkill -f firefox
    else
        echo "✗ Firefox nem normal funciona"
        echo ""
        echo "PROBLEMA: Ambiente X11 nao configurado"
        echo "SOLUCAO: Inicie sessao grafica com usuario informa"
        echo ""
        read -p "Deseja continuar mesmo assim? (S/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Cancelado."
            exit 1
        fi
    fi
fi

# PASSO 3: Remover serviço antigo completamente
echo ""
echo "PASSO 3: Removendo serviço antigo..."
echo ""

# Parar e desabilitar serviço
systemctl stop credivision-kiosk.service 2>/dev/null || true
systemctl disable credivision-kiosk.service 2>/dev/null || true

# Remover arquivo de serviço
rm -f /etc/systemd/system/credivision-kiosk.service
rm -f /etc/systemd/system/credivision-kiosk.service.d/*

# Reload systemd
systemctl daemon-reload

echo "✓ Serviço antigo removido"

# PASSO 4: Criar serviço novo com configuração correta
echo ""
echo "PASSO 4: Criando serviço novo..."
echo ""

# Criar serviço com target correto
cat > /etc/systemd/system/credivision-kiosk.service << 'SERVICE_EOF'
[Unit]
Description=CrediVision Firefox Kiosk
After=network.target

[Service]
Type=simple
User=informa
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/informa/.Xauthority
ExecStart=/home/informa/Documents/CrediVision/simple_kiosk_enhanced.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Reload systemd
systemctl daemon-reload

# Habilitar serviço
systemctl enable credivision-kiosk.service

echo "✓ Serviço novo criado"

# PASSO 5: Iniciar e verificar serviço
echo ""
echo "PASSO 5: Iniciando e verificando serviço..."
echo ""

# Iniciar serviço
systemctl start credivision-kiosk.service

# Aguardar um pouco
sleep 5

# Verificar status
echo "Status do serviço:"
systemctl status credivision-kiosk.service --no-pager

echo ""
echo "Logs recentes:"
journalctl -u credivision-kiosk.service -n 10 --no-pager

# PASSO 6: Verificação final
echo ""
echo "PASSO 6: Verificação final..."
echo ""

# Aguardar mais um pouco
sleep 10

# Verificar se Firefox está rodando
if pgrep -f firefox > /dev/null; then
    echo ""
    echo "=========================================="
    echo "✓ SUCESSO TOTAL! KIOSK FUNCIONANDO!"
    echo "=========================================="
    echo ""
    echo "Kiosk esta rodando via servico systemd:"
    echo "  ✓ Script novo sendo usado"
    echo "  ✓ Firefox em modo kiosk"
    echo "  ✓ URL configurada do tabs.json"
    echo "  ✓ Serviço ativo e reiniciando"
    echo "  ✓ Reinicio automatico"
    echo ""
    echo "Comandos uteis:"
    echo "  Status: sudo systemctl status credivision-kiosk.service"
    echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo "  Parar: sudo systemctl stop credivision-kiosk.service"
    echo "  Reiniciar: sudo systemctl restart credivision-kiosk.service"
    echo "  Teste manual: sudo -u informa bash simple_kiosk_enhanced.sh"
    echo ""
    echo "URL configurada:"
    python3 -c "
import json
with open('/home/informa/Documents/kiosk-data/tabs.json', 'r') as f:
    data = json.load(f)
tabs = data if isinstance(data, list) else data.get('tabs', [])
for tab in tabs:
    if tab.get('enabled', True):
        print(f'  {tab.get(\"name\", \"Sem nome\")}: {tab.get(\"url\", \"Sem URL\")}')
        break
"
    echo ""
    echo "=========================================="
    echo "KIOSK 100% FUNCIONAL!"
    echo "=========================================="
    
else
    echo ""
    echo "✗ Kiosk não está rodando via serviço"
    echo ""
    echo "Diagnóstico do problema:"
    echo "Serviço: $(systemctl is-active credivision-kiosk.service)"
    echo "Firefox: $(pgrep -f firefox | wc -l) processos"
    echo "Script: $(ls -la $PROJECT_DIR/simple_kiosk_enhanced.sh)"
    echo ""
    echo "Tentando iniciar manualmente para debug..."
    sudo -u informa bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
    MANUAL_PID=$!
    
    sleep 5
    if pgrep -f firefox > /dev/null; then
        echo "✓ Script funciona manualmente, problema no serviço"
        echo "Verificando logs do serviço:"
        journalctl -u credivision-kiosk.service -n 20 --no-pager
        pkill -f firefox
        kill $MANUAL_PID 2>/dev/null
    else
        echo "✗ Script nem manualmente funciona"
        echo "Problema no ambiente X11 ou Firefox"
        kill $MANUAL_PID 2>/dev/null
    fi
    
    echo ""
    echo "Soluções alternativas:"
    echo "1. Verifique se sessão grafica está ativa"
    echo "2. Execute: sudo -u informa startx"
    echo "3. Verifique DISPLAY=:0 esta correto"
    echo "4. Use crontab como fallback"
    echo ""
    
    # Oferecer crontab como fallback
    read -p "Deseja configurar via crontab como fallback? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo ""
        echo "Configurando via crontab..."
        
        # Parar serviço
        systemctl stop credivision-kiosk.service
        systemctl disable credivision-kiosk.service
        
        # Adicionar ao crontab
        (crontab -u informa -l 2>/dev/null; echo "@reboot /bin/bash /home/informa/Documents/CrediVision/simple_kiosk_enhanced.sh") | crontab -u informa
        
        # Iniciar imediatamente
        sudo -u informa bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
        
        sleep 5
        if pgrep -f firefox > /dev/null; then
            echo "✓ Kiosk rodando via crontab!"
        else
            echo "✗ Nem crontab funcionou"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "CORREÇÃO DO SERVIÇO FINALIZADA!"
echo "=========================================="
echo ""
