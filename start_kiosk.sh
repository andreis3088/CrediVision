#!/bin/bash

# Script para iniciar o CrediVision Kiosk em modo tela cheia
# Usa Firefox com o novo display_kiosk.html

echo "Iniciando CrediVision Kiosk..."

# Verificar se o Firefox está instalado
if ! command -v firefox &> /dev/null; then
    echo "ERRO: Firefox não está instalado!"
    echo "Instale com: sudo apt install firefox"
    exit 1
fi

# Verificar se a aplicação está rodando
if ! curl -s http://localhost:5000/api/config > /dev/null; then
    echo "ERRO: Aplicação CrediVision não está respondendo!"
    echo "Verifique: sudo systemctl status credivision-app.service"
    exit 1
fi

# Obter IP local
IP=$(hostname -I | awk '{print $1}')

# Opções de inicialização
case "${1:-normal}" in
    "debug")
        echo "Iniciando em modo DEBUG (janela normal)..."
        firefox --new-window "http://localhost:5000/display_kiosk" &
        ;;
    "fullscreen")
        echo "Iniciando em modo TELA CHEIA..."
        firefox --kiosk --fullscreen "http://localhost:5000/display_kiosk" &
        ;;
    "window")
        echo "Iniciando em modo JANELA..."
        firefox --new-window --width=1280 --height=720 "http://localhost:5000/display_kiosk" &
        ;;
    *)
        echo "Iniciando em modo KIOSK padrão..."
        firefox --kiosk "http://localhost:5000/display_kiosk" &
        ;;
esac

echo "Kiosk iniciado!"
echo "URL: http://$IP:5000/display_kiosk"
echo ""
echo "Atalhos:"
echo "  Ctrl+Shift+R: Recarregar página"
echo "  Ctrl+Shift+S: Mostrar status"
echo ""
echo "Para iniciar em outros modos:"
echo "  sudo bash start_kiosk.sh debug     - Janela normal"
echo "  sudo bash start_kiosk.sh fullscreen - Tela cheia"
echo "  sudo bash start_kiosk.sh window    - Janela 1280x720"
