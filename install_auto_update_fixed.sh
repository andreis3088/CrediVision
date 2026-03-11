#!/bin/bash

# Script corrigido para instalar atualização automática

echo "=========================================="
echo "Instalando Atualização Automática (FIXED)"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash install_auto_update_fixed.sh"
    exit 1
fi

# Detectar usuário correto
if [ -d "/home/informa" ]; then
    SERVICE_USER="informa"
elif [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    SERVICE_USER="$SUDO_USER"
else
    echo "ERRO: Não foi possível determinar o usuário"
    echo "Execute: sudo -u informa bash install_auto_update_fixed.sh"
    exit 1
fi

PROJECT_DIR="/home/$SERVICE_USER/Documentos/CrediVision"
echo "Usuário: $SERVICE_USER"
echo "Diretório: $PROJECT_DIR"
echo ""

# Verificar se o diretório do projeto existe
if [ ! -d "$PROJECT_DIR" ]; then
    echo "ERRO: Diretório do projeto não encontrado: $PROJECT_DIR"
    echo "Verifique se o CrediVision está instalado corretamente"
    exit 1
fi

# Verificar se os arquivos necessários existem
if [ ! -f "$PROJECT_DIR/auto_update_kiosk.py" ]; then
    echo "ERRO: auto_update_kiosk.py não encontrado"
    echo "Copie os arquivos do projeto para o servidor primeiro"
    exit 1
fi

echo "PASSO 1: Instalando dependências..."

# Instalar dependências
apt update
apt install -y python3-pip python3-watchdog

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
echo "Sistema de atualização automática instalado!"
echo ""
echo "Comandos úteis:"
echo "  Ver status: sudo systemctl status credivision-auto-update.service"
echo "  Ver logs: sudo journalctl -u credivision-auto-update.service -f"
echo "  Parar: sudo systemctl stop credivision-auto-update.service"
echo "  Iniciar: sudo systemctl start credivision-auto-update.service"
echo ""
echo "Para testar:"
echo "  1. Adicione uma nova aba na interface web"
echo "  2. Aguarde até 10 segundos"
echo "  3. O kiosk deve reiniciar automaticamente"
echo ""
echo "Logs em tempo real:"
echo "  sudo tail -f /tmp/credivision_auto_update.log"
echo ""
