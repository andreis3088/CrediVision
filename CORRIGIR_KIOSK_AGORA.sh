#!/bin/bash

echo "=========================================="
echo "CORRIGINDO KIOSK - Versao Simples"
echo "=========================================="
echo ""

# Verificar se esta rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash CORRIGIR_KIOSK_AGORA.sh"
    exit 1
fi

PROJECT_DIR="/home/informa/Documentos/CrediVision"

echo "PROBLEMA: Kiosk nao abre Firefox"
echo "SOLUCAO: Substituir por versao simples e funcional"
echo ""

# Fazer backup do script atual
if [ -f "$PROJECT_DIR/simple_kiosk_enhanced.sh" ]; then
    cp "$PROJECT_DIR/simple_kiosk_enhanced.sh" "$PROJECT_DIR/simple_kiosk_enhanced.sh.old"
    echo "Backup criado: simple_kiosk_enhanced.sh.old"
fi

# Substituir por versao simples
cp "$PROJECT_DIR/KIOSK_SIMPLES_FUNCIONAL.sh" "$PROJECT_DIR/simple_kiosk_enhanced.sh"
chmod +x "$PROJECT_DIR/simple_kiosk_enhanced.sh"
chown informa:informa "$PROJECT_DIR/simple_kiosk_enhanced.sh"

echo "Script do kiosk substituido por versao simples!"

echo ""
echo "TESTANDO KIOSK..."
echo ""

# Testar manualmente
echo "Executando teste manual..."
sudo -u informa bash "$PROJECT_DIR/simple_kiosk_enhanced.sh" &
KIOSK_PID=$!

echo "Aguardando 10 segundos..."
sleep 10

# Verificar se Firefox esta rodando
if pgrep -f firefox > /dev/null; then
    echo "✓ SUCESSO: Firefox esta rodando!"
    echo "Kiosk funcional!"
    
    # Parar teste
    kill $KIOSK_PID 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    
    echo ""
    echo "Reiniciando servico kiosk..."
    systemctl restart credivision-kiosk.service
    
    echo ""
    echo "=========================================="
    echo "KIOSK CORRIGIDO COM SUCESSO!"
    echo "=========================================="
    echo ""
    echo "O kiosk agora:"
    echo "  ✓ Le configuracao das abas"
    echo "  ✓ Abre Firefox em modo kiosk"
    echo "  ✓ Tela cheia real"
    echo "  ✓ Funciona com qualquer URL"
    echo ""
    echo "Para testar manualmente:"
    echo "  sudo -u informa bash simple_kiosk_enhanced.sh"
    echo ""
    echo "Para verificar servico:"
    echo "  sudo journalctl -u credivision-kiosk.service -f"
    echo ""
    
else
    echo "✗ FALHA: Firefox nao iniciou"
    
    # Parar teste
    kill $KIOSK_PID 2>/dev/null || true
    
    echo ""
    echo "Diagnosticando problema..."
    echo ""
    
    # Verificar Firefox
    if command -v firefox &> /dev/null; then
        echo "✓ Firefox instalado: $(firefox --version)"
    else
        echo "✗ Firefox nao instalado"
        echo "  Instale com: sudo apt install firefox"
    fi
    
    # Verificar ambiente X11
    echo ""
    echo "Ambiente X11:"
    echo "  DISPLAY: ${DISPLAY:-:0}"
    echo "  XAUTHORITY: ${XAUTHORITY:-/home/informa/.Xauthority}"
    echo "  Usuario: informa"
    
    # Verificar sessao X11
    if pgrep Xorg > /dev/null; then
        echo "  ✓ Sessao X11 rodando"
    else
        echo "  ✗ Sessao X11 nao encontrada"
        echo "  Inicie a sessao grafica primeiro"
    fi
    
    # Verificar se usuario informa tem permissao
    echo ""
    echo "Permissoes do usuario informa:"
    groups informa
    
    echo ""
    echo "Solucoes possiveis:"
    echo "  1. Inicie sessao grafica com usuario informa"
    echo "  2. Verifique se DISPLAY esta correto"
    echo "  3. Execute manualmente na sessao grafica:"
    echo "     firefox --kiosk http://google.com"
    echo ""
fi

echo ""
echo "Arquivos modificados:"
echo "  simple_kiosk_enhanced.sh (substituido)"
echo "  simple_kiosk_enhanced.sh.old (backup)"
echo ""
