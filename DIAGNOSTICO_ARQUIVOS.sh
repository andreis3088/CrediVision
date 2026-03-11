#!/bin/bash

echo "=========================================="
echo "DIAGNÓSTICO DE ARQUIVOS DE MÍDIA"
echo "=========================================="
echo ""

# Verificar diretório de mídia
MEDIA_DIR="/home/informa/Documents/kiosk-media"
TABS_FILE="/home/informa/Documents/kiosk-data/tabs.json"

echo "1. VERIFICANDO DIRETÓRIO DE MÍDIA:"
echo "   Caminho: $MEDIA_DIR"
if [ -d "$MEDIA_DIR" ]; then
    echo "   ✓ Diretório existe"
    echo "   Arquivos encontrados:"
    ls -la "$MEDIA_DIR" | grep -E '\.(jpg|jpeg|png|gif|mp4|avi|mov|mkv|webm)$' || echo "   Nenhum arquivo de mídia encontrado"
else
    echo "   ✗ Diretório NÃO existe"
fi
echo ""

echo "2. VERIFICANDO ARQUIVO tabs.json:"
echo "   Caminho: $TABS_FILE"
if [ -f "$TABS_FILE" ]; then
    echo "   ✓ Arquivo existe"
    echo "   Conteúdo:"
    cat "$TABS_FILE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tabs = data if isinstance(data, list) else data.get('tabs', [])
    for i, tab in enumerate(tabs):
        if tab.get('enabled', True):
            print(f'   {i+1}. {tab.get(\"name\", \"Sem nome\")}')
            print(f'      URL: \"{tab.get(\"url\", \"Sem URL\")}\"')
            print(f'      Tipo: {tab.get(\"type\", \"url\")}')
            print(f'      Ativa: {tab.get(\"enabled\", False)}')
            print()
except Exception as e:
    print(f'   ERRO ao ler JSON: {e}')
"
else
    echo "   ✗ Arquivo NÃO existe"
fi
echo ""

echo "3. VERIFICANDO SERVIDOR FLASK:"
if systemctl is-active --quiet credivision-app.service; then
    echo "   ✓ Serviço Flask está ativo"
    echo "   Testando acesso aos arquivos:"
    
    # Listar arquivos e testar cada um
    if [ -d "$MEDIA_DIR" ]; then
        for file in "$MEDIA_DIR"/*; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                url="http://localhost:5000/media/$filename"
                echo "   Testando: $url"
                if curl -s -I "$url" | head -1 | grep -q "200\|404"; then
                    status=$(curl -s -I "$url" | head -1)
                    echo "   $status"
                else
                    echo "   ✗ Falha ao acessar"
                fi
            fi
        done
    fi
else
    echo "   ✗ Serviço Flask NÃO está ativo"
    echo "   Status: $(systemctl is-active credivision-app.service)"
fi
echo ""

echo "4. VERIFICANDO PERMISSÕES:"
if [ -d "$MEDIA_DIR" ]; then
    echo "   Dono do diretório: $(stat -c '%U:%G' "$MEDIA_DIR")"
    echo "   Permissões: $(stat -c '%a' "$MEDIA_DIR")"
    
    for file in "$MEDIA_DIR"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "   $filename: $(stat -c '%U:%G %a' "$file")"
        fi
    done
fi
echo ""

echo "5. TESTE MANUAL DE URL:"
if [ -f "$TABS_FILE" ]; then
    echo "   URLs que serão usadas:"
    cat "$TABS_FILE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    tabs = data if isinstance(data, list) else data.get('tabs', [])
    for tab in tabs:
        if tab.get('enabled', True) and tab.get('type') in ['image', 'video']:
            url = tab.get('url', '')
            print(f'   {tab.get(\"name\")}: \"{url}\"')
            
            # Verificar tipo de URL
            if url.startswith('http://localhost:5000/media/'):
                print('   → URL HTTP completa ✓')
            elif url.startswith('/media/'):
                print('   → URL relativa /media/ (precisa conversão)')
            elif url.startswith('/'):
                print('   → Caminho local absoluto')
            else:
                print('   → URL externa')
            print()
except Exception as e:
    print(f'   ERRO: {e}')
"
fi

echo "=========================================="
echo "DIAGNÓSTICO CONCLUÍDO"
echo "=========================================="
echo ""
echo "Se encontrar problemas, execute:"
echo "1. Corrigir permissões: sudo chown -R informa:informa $MEDIA_DIR"
echo "2. Reiniciar Flask: sudo systemctl restart credivision-app.service"
echo "3. Reenviar arquivos pela interface web"
echo ""
