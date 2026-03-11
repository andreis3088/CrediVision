#!/bin/bash

# Script para instalar o sistema de atualização automática do CrediVision

echo "=========================================="
echo "Instalando Atualização Automática"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash install_auto_update.sh"
    exit 1
fi

# Obter usuário atual
SERVICE_USER="${SUDO_USER:-$USER}"
PROJECT_DIR="/home/$SERVICE_USER/Documentos/CrediVision"

echo "Usuário: $SERVICE_USER"
echo "Diretório: $PROJECT_DIR"
echo ""

echo "PASSO 1: Instalando dependências Python..."

# Instalar dependências
apt update
apt install -y python3-pip python3-watchdog

# Instalar watchdog se necessário
pip3 install watchdog 2>/dev/null || true

echo ""
echo "PASSO 2: Configurando serviço systemd..."

# Criar serviço de atualização automática
cat > /etc/systemd/system/credivision-auto-update.service << EOF
[Unit]
Description=CrediVision Auto Update Service
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/usr/bin/python3 $PROJECT_DIR/auto_update_kiosk.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd e habilitar serviço
systemctl daemon-reload
systemctl enable credivision-auto-update.service

echo ""
echo "PASSO 3: Configurando permissões..."

# Configurar permissões
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/auto_update_kiosk.py"
chmod +x "$PROJECT_DIR/auto_update_kiosk.py"

echo ""
echo "PASSO 4: Testando atualizador..."

# Testar em modo debug
echo "Testando atualizador em modo debug..."
sudo -u "$SERVICE_USER" python3 "$PROJECT_DIR/auto_update_kiosk.py" --test

echo ""
echo "PASSO 5: Iniciando serviço..."

# Iniciar serviço
systemctl start credivision-auto-update.service

# Aguardar um momento
sleep 3

# Verificar status
if systemctl is-active --quiet credivision-auto-update.service; then
    echo "✓ Serviço de atualização automática iniciado"
else
    echo "✗ Falha ao iniciar serviço"
    echo "Logs:"
    journalctl -u credivision-auto-update.service -n 10
fi

echo ""
echo "=========================================="
echo "Instalação Concluída!"
echo "=========================================="
echo ""
echo "Sistema de atualização automática instalado:"
echo ""
echo "Métodos de detecção:"
echo "  • API polling (a cada 5 segundos)"
echo "  • Monitoramento de arquivos (tabs.json)"
echo "  • Webhook (via interface admin)"
echo ""
echo "Comandos úteis:"
echo "  Ver status: sudo systemctl status credivision-auto-update.service"
echo "  Ver logs: sudo journalctl -u credivision-auto-update.service -f"
echo "  Parar serviço: sudo systemctl stop credivision-auto-update.service"
echo "  Iniciar serviço: sudo systemctl start credivision-auto-update.service"
echo ""
echo "Como funciona:"
echo "  1. Quando você adiciona/edita/remove abas na interface"
echo "  2. O sistema detecta automaticamente"
echo "  3. O kiosk é reiniciado com nova configuração"
echo "  4. Notificação é exibida na tela"
echo ""
echo "Arquivos de log:"
echo "  • Systemd: journalctl -u credivision-auto-update.service"
echo "  • Aplicação: /tmp/credivision_auto_update.log"
echo ""
echo "Para testar manualmente:"
echo "  sudo -u $SERVICE_USER python3 $PROJECT_DIR/auto_update_kiosk.py --test"
echo ""
