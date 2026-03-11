#!/bin/bash

# Script para instalar/atualizar o novo sistema Kiosk do CrediVision

echo "=========================================="
echo "Instalando Novo Sistema Kiosk"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash install_kiosk.sh"
    exit 1
fi

# Obter usuário atual
SERVICE_USER="${SUDO_USER:-$USER}"
PROJECT_DIR="/home/$SERVICE_USER/Documentos/CrediVision"

echo "Usuário: $SERVICE_USER"
echo "Diretório: $PROJECT_DIR"
echo ""

echo "PASSO 1: Parar serviço kiosk antigo..."
systemctl stop credivision-kiosk.service 2>/dev/null || true
systemctl disable credivision-kiosk.service 2>/dev/null || true

echo ""
echo "PASSO 2: Instalar Firefox (se necessário)..."
apt update
apt install -y firefox

echo ""
echo "PASSO 3: Configurar ambiente X11..."
# Garantir que o usuário pode acessar o display X11
usermod -a -G input $SERVICE_USER
usermod -a -G video $SERVICE_USER

echo ""
echo "PASSO 4: Instalar novo serviço kiosk..."
cp "$PROJECT_DIR/credivision-kiosk.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable credivision-kiosk.service

echo ""
echo "PASSO 5: Configurar permissões..."
chmod +x "$PROJECT_DIR/start_kiosk.sh"
chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/start_kiosk.sh"

echo ""
echo "PASSO 6: Testar script kiosk..."
echo "Testando script em modo debug..."
sudo -u $SERVICE_USER "$PROJECT_DIR/start_kiosk.sh debug" &
sleep 5
pkill -f "firefox.*display_kiosk" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Instalação Concluída!"
echo "=========================================="
echo ""
echo "O novo sistema kiosk:"
echo "- Usa Firefox em modo tela cheia"
echo "- Exibe sites diretamente (sem iframe)"
echo "- Suporta imagens e vídeos em tela cheia"
echo "- Rotação automática de conteúdo"
echo ""
echo "Comandos úteis:"
echo "  Iniciar kiosk: sudo systemctl start credivision-kiosk.service"
echo "  Parar kiosk: sudo systemctl stop credivision-kiosk.service"
echo "  Ver status: sudo systemctl status credivision-kiosk.service"
echo "  Testar manual: sudo -u $SERVICE_USER $PROJECT_DIR/start_kiosk.sh debug"
echo ""
echo "URL do kiosk: http://$(hostname -I | awk '{print $1}'):5000/display_kiosk"
echo ""
echo "Para reiniciar com novo kiosk:"
echo "  sudo systemctl restart credivision-kiosk.service"
echo ""
