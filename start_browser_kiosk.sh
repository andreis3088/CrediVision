#!/bin/bash

# Script para iniciar kiosk com abas reais do navegador
# Abre cada URL em uma aba separada e rotaciona entre elas

echo "Iniciando CrediVision Browser Kiosk..."

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

# Obter configuração das abas
CONFIG_FILE="/tmp/credivision_tabs.json"
curl -s http://localhost:5000/api/config > "$CONFIG_FILE"

# Verificar se há abas configuradas
if [ ! -s "$CONFIG_FILE" ]; then
    echo "ERRO: Nenhuma aba configurada!"
    exit 1
fi

# Extrair URLs das abas ativas
URLS_FILE="/tmp/credivision_urls.txt"
python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
    urls = []
    for tab in data.get('tabs', []):
        if tab.get('active', True) and tab.get('content_type') == 'url':
            urls.append(tab['url'])
        elif tab.get('active', True) and tab.get('content_type') in ['image', 'video']:
            # Criar página HTML local para imagens/vídeos
            if tab.get('content_type') == 'image':
                html = f'''<!DOCTYPE html>
<html>
<head><title>{tab['name']}</title></head>
<body style='margin:0;padding:0;background:#000;display:flex;align-items:center;justify-content:center;height:100vh;'>
<img src='{tab['url']}' style='max-width:100%;max-height:100vh;object-fit:contain;' alt='{tab['name']}'>
</body>
</html>'''
            else:  # video
                html = f'''<!DOCTYPE html>
<html>
<head><title>{tab['name']}</title></head>
<body style='margin:0;padding:0;background:#000;display:flex;align-items:center;justify-content:center;height:100vh;'>
<video autoplay muted loop style='max-width:100%;max-height:100vh;object-fit:contain;'>
<source src='{tab['url']}'>
</video>
</body>
</html>'''
            with open(f'/tmp/credivision_{tab['id']}.html', 'w') as f:
                f.write(html)
            urls.append(f'file:///tmp/credivision_{tab['id']}.html')
    
    with open('$URLS_FILE', 'w') as f:
        for url in urls:
            f.write(url + '\n')
"

if [ ! -s "$URLS_FILE" ]; then
    echo "ERRO: Nenhuma URL válida encontrada!"
    exit 1
fi

# Ler URLs
URLS=($(cat "$URLS_FILE"))
echo "Encontradas ${#URLS[@]} URLs para exibir"

# Iniciar Firefox com as abas
echo "Iniciando Firefox com ${#URLS[@]} abas..."

# Criar perfil do Firefox para kiosk
PROFILE_DIR="/home/$SUDO_USER/.mozilla/firefox/credivision-kiosk"
if [ ! -d "$PROFILE_DIR" ]; then
    mkdir -p "$PROFILE_DIR"
    chown -R $SUDO_USER:$SUDO_USER "$PROFILE_DIR"
fi

# Iniciar Firefox em modo kiosk com todas as abas
case "${1:-normal}" in
    "debug")
        echo "Iniciando em modo DEBUG..."
        firefox --new-instance --profile "$PROFILE_DIR" "${URLS[@]}" &
        ;;
    "fullscreen")
        echo "Iniciando em modo TELA CHEIA..."
        firefox --kiosk --new-instance --profile "$PROFILE_DIR" "${URLS[@]}" &
        ;;
    "window")
        echo "Iniciando em modo JANELA..."
        firefox --new-instance --profile "$PROFILE_DIR" --width=1280 --height=720 "${URLS[@]}" &
        ;;
    *)
        echo "Iniciando em modo KIOSK padrão..."
        firefox --kiosk --new-instance --profile "$PROFILE_DIR" "${URLS[@]}" &
        ;;
esac

# Aguardar Firefox iniciar
sleep 3

# Instalar extensão para rotação de abas (se necessário)
echo "Configurando rotação automática..."

# Criar script de rotação
ROTATION_SCRIPT="/tmp/credivision_rotation.js"
cat > "$ROTATION_SCRIPT" << 'EOF'
// Script para rotação automática de abas
let currentTab = 0;
let rotationInterval;

function rotateTabs() {
    const tabs = gBrowser.tabs;
    if (tabs.length <= 1) return;
    
    currentTab = (currentTab + 1) % tabs.length;
    gBrowser.selectedTab = tabs[currentTab];
    
    // Mostrar nome da aba (opcional)
    const tab = tabs[currentTab];
    console.log('Rotating to tab:', tab.label || 'Untitled');
}

function startRotation() {
    // Parar rotação existente
    if (rotationInterval) {
        clearInterval(rotationInterval);
    }
    
    // Iniciar nova rotação (5 minutos por padrão)
    rotationInterval = setInterval(rotateTabs, 300000); // 5 minutos
}

function stopRotation() {
    if (rotationInterval) {
        clearInterval(rotationInterval);
        rotationInterval = null;
    }
}

// Iniciar rotação quando a janela estiver pronta
setTimeout(startRotation, 5000);

// Atalhos de teclado
window.addEventListener('keydown', function(event) {
    if (event.ctrlKey && event.shiftKey) {
        switch(event.key) {
            case 'R':
                location.reload();
                break;
            case 'N':
                rotateTabs();
                break;
            case 'S':
                stopRotation();
                break;
            case 'T':
                startRotation();
                break;
        }
    }
});
EOF

# Injetar script de rotação (via user.js)
USER_JS_FILE="$PROFILE_DIR/user.js"
cat > "$USER_JS_FILE" << 'EOF'
// CrediVision Kiosk Configuration
user_pref("browser.fullscreen.autohide", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.tabs.animate", false);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.newtab.url", "about:blank");
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("dom.disable_window_move_resize", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
EOF

echo "Kiosk iniciado com ${#URLS[@]} abas!"
echo ""
echo "Atalhos:"
echo "  Ctrl+Shift+N: Próxima aba"
echo "  Ctrl+Shift+R: Recarregar página atual"
echo "  Ctrl+Shift+S: Parar rotação"
echo "  Ctrl+Shift+T: Iniciar rotação"
echo ""
echo "Para iniciar em outros modos:"
echo "  sudo bash start_browser_kiosk.sh debug     - Janela normal"
echo "  sudo bash start_browser_kiosk.sh fullscreen - Tela cheia"
echo "  sudo bash start_browser_kiosk.sh window    - Janela 1280x720"

# Limpar arquivos temporários
trap "rm -f $CONFIG_FILE $URLS_FILE $ROTATION_SCRIPT" EXIT
