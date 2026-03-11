#!/bin/bash

echo "=========================================="
echo "CORREÇÃO COMPLETA - Kiosk Firefox Normal"
echo "=========================================="
echo ""

# Verificar se esta rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash CORRECAO_COMPLETA_FINAL.sh"
    exit 1
fi

SERVICE_USER="informa"
PROJECT_DIR="/home/informa/Documentos/CrediVision"
DATA_DIR="/home/informa/Documents/kiosk-data"

echo "Usuario: $SERVICE_USER"
echo "Projeto: $PROJECT_DIR"
echo ""

# PASSO 1: Verificar estrutura do arquivo tabs
echo "PASSO 1: Verificando estrutura do tabs.json..."
echo ""

if [ ! -f "$DATA_DIR/tabs.json" ]; then
    echo "ERRO: Arquivo tabs.json nao encontrado!"
    exit 1
fi

# Verificar estrutura com Python
python3 << 'PYTHON_EOF'
import json
import sys

try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    print("Estrutura do arquivo:")
    if isinstance(data, list):
        print("  - Tipo: Lista direta")
        tabs = data
    else:
        print("  - Tipo: Objeto com chave 'tabs'")
        tabs = data.get("tabs", [])
    
    print(f"  - Total abas: {len(tabs)}")
    
    print("\nAbas configuradas:")
    for i, tab in enumerate(tabs):
        name = tab.get("name", "Sem nome")
        url = tab.get("url", "Sem URL")
        enabled = tab.get("enabled", True)
        tab_type = tab.get("type", "url")
        
        print(f"  {i+1}. {name}")
        print(f"     URL: {url}")
        print(f"     Tipo: {tab_type}")
        print(f"     Ativa: {enabled}")
        print()
    
    # Procurar primeira aba ativa
    active_tab = None
    for tab in tabs:
        if tab.get("enabled", True):
            active_tab = tab
            break
    
    if active_tab:
        url = active_tab.get("url", "").strip()
        name = active_tab.get("name", "").strip()
        
        if url:
            print(f"PRIMEIRA ABA ATIVA:")
            print(f"  Nome: {name}")
            print(f"  URL: {url}")
            
            # Salvar URL em arquivo temporario
            with open("/tmp/kiosk_url.txt", "w") as f:
                f.write(url)
            
            print("✓ URL salva em /tmp/kiosk_url.txt")
        else:
            print("ERRO: Primeira aba ativa nao tem URL")
            sys.exit(1)
    else:
        print("ERRO: Nenhuma aba ativa encontrada")
        sys.exit(1)
        
except Exception as e:
    print(f"ERRO ao ler arquivo: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
    echo "ERRO: Falha ao processar tabs.json"
    exit 1
fi

# Ler URL do arquivo temporario
URL=$(cat /tmp/kiosk_url.txt 2>/dev/null)
if [ -z "$URL" ]; then
    echo "ERRO: URL nao encontrada"
    exit 1
fi

echo "URL para o kiosk: $URL"
echo ""

# PASSO 2: Verificar Firefox
echo "PASSO 2: Verificando Firefox..."
if ! command -v firefox &> /dev/null; then
    echo "Firefox nao encontrado. Instalando..."
    apt update
    apt install -y firefox
else
    echo "✓ Firefox encontrado: $(firefox --version)"
fi

# PASSO 3: Verificar ambiente X11
echo "PASSO 3: Configurando ambiente X11..."
echo ""

# Configurar usuario
usermod -a -G audio,video,input,plugdev,render "$SERVICE_USER"

# Configurar X11 wrapper
if [ ! -f "/etc/X11/Xwrapper.config" ]; then
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
fi

# Configurar bashrc do usuario
cat >> "/home/$SERVICE_USER/.bashrc" << 'BASHRC_EOF'

# Configuracoes X11 para CrediVision
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority
BASHRC_EOF

echo "✓ Ambiente X11 configurado"

# PASSO 4: Criar script kiosk simples e funcional
echo "PASSO 4: Criando script kiosk..."
echo ""

# Fazer backup do script antigo
if [ -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
    cp "$PROJECT_DIR/simple_kiosk_enhanced.sh" "$PROJECT_DIR/simple_kiosk_enhanced.sh.backup"
fi

# Criar novo script
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
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/simple_kiosk_enhanced.sh"

echo "✓ Script kiosk criado"

# PASSO 5: Testar kiosk manualmente
echo "PASSO 5: Testando kiosk manualmente..."
echo ""

echo "Iniciando kiosk por 10 segundos para teste..."
sudo -u "$SERVICE_USER" bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
KIOSK_PID=$!

sleep 10

# Verificar se funcionou
if pgrep -f firefox > /dev/null; then
    echo "✓ Kiosk funcionou manualmente!"
    echo "Parando teste..."
    kill $KIOSK_PID 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    sleep 2
else
    echo "✗ Kiosk nao funcionou manualmente"
    echo "Verificando problemas..."
    
    # Verificar ambiente
    echo "DISPLAY: $DISPLAY"
    echo "Usuario: $(whoami)"
    echo "Firefox: $(which firefox)"
    
    # Tentar iniciar Firefox sem kiosk
    echo "Tentando Firefox normal..."
    sudo -u "$SERVICE_USER" firefox &
    sleep 5
    
    if pgrep -f firefox > /dev/null; then
        echo "✓ Firefox normal funciona, problema eh modo kiosk"
        pkill -f firefox
    else
        echo "✗ Firefox nem normal funciona"
        echo "Problema pode ser ambiente X11"
    fi
    
    echo ""
    echo "Solucoes possiveis:"
    echo "1. Inicie sessao grafica com usuario informa"
    echo "2. Verifique se DISPLAY=:0 esta correto"
    echo "3. Execute manualmente na sessao grafica"
    echo ""
    
    read -p "Deseja continuar mesmo assim? (S/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Cancelado."
        exit 1
    fi
fi

# PASSO 6: Configurar servico systemd
echo "PASSO 6: Configurando servico systemd..."
echo ""

# Parar servico atual
systemctl stop credivision-kiosk.service 2>/dev/null || true

# Criar servico simples
cat > /etc/systemd/system/credivision-kiosk.service << 'SERVICE_EOF'
[Unit]
Description=CrediVision Firefox Kiosk
After=graphical-session.target

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
WantedBy=graphical-session.target
SERVICE_EOF

# Reload systemd
systemctl daemon-reload

# Habilitar e iniciar servico
systemctl enable credivision-kiosk.service
systemctl start credivision-kiosk.service

echo "✓ Servico systemd configurado"

# PASSO 7: Verificar servico
echo "PASSO 7: Verificando servico..."
echo ""

sleep 5
echo "Status do servico:"
systemctl status credivision-kiosk.service --no-pager

echo ""
echo "Logs do servico:"
journalctl -u credivision-kiosk.service -n 10 --no-pager

# PASSO 8: Teste final
echo ""
echo "PASSO 8: Teste final..."
echo ""

sleep 10
if pgrep -f firefox > /dev/null; then
    echo "✓ Kiosk esta rodando via servico!"
    echo ""
    echo "=========================================="
    echo "CORREÇÃO COMPLETA CONCLUIDA COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "Kiosk funcionando:"
    echo "  ✓ URL configurada: $URL"
    echo "  ✓ Firefox em modo kiosk"
    echo "  ✓ Servico systemd ativo"
    echo "  ✓ Reinicio automatico"
    echo ""
    echo "Comandos uteis:"
    echo "  Status: sudo systemctl status credivision-kiosk.service"
    echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo "  Parar: sudo systemctl stop credivision-kiosk.service"
    echo "  Iniciar: sudo systemctl start credivision-kiosk.service"
    echo "  Teste manual: sudo -u informa bash simple_kiosk_enhanced.sh"
    echo ""
else
    echo "✗ Kiosk nao esta rodando via servico"
    echo ""
    echo "Verificando problemas..."
    echo "Servico: $(systemctl is-active credivision-kiosk.service)"
    echo "Firefox: $(pgrep -f firefox | wc -l) processos"
    
    echo ""
    echo "Tentando iniciar manualmente..."
    sudo -u "$SERVICE_USER" bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
    
    sleep 5
    if pgrep -f firefox > /dev/null; then
        echo "✓ Funciona manualmente, problema no servico"
        echo "Verifique os logs acima"
    else
        echo "✗ Nem manualmente funciona"
        echo "Problema no ambiente X11 ou Firefox"
    fi
fi

# Limpar arquivo temporario
rm -f /tmp/kiosk_url.txt

echo ""
echo "=========================================="
echo "CORREÇÃO COMPLETA FINALIZADA!"
echo "=========================================="
echo ""
