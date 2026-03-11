#!/bin/bash

# Script para sincronizar arquivos do projeto para o servidor

echo "=========================================="
echo "Sincronizando Arquivos do CrediVision"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash sync_files.sh"
    exit 1
fi

# Diretórios
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/home/informa/Documentos/CrediVision"

echo "Diretório origem: $SOURCE_DIR"
echo "Diretório destino: $TARGET_DIR"
echo ""

# Criar diretório destino se não existir
mkdir -p "$TARGET_DIR"

# Arquivos essenciais para copiar
ESSENTIAL_FILES=(
    "auto_update_kiosk.py"
    "simple_kiosk.sh"
    "simple_kiosk_enhanced.sh"
    "manage_with_auto_update.sh"
    "test_media.sh"
    "force_stop_all.sh"
    "install_auto_update_fixed.sh"
)

echo "Copiando arquivos essenciais..."
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$TARGET_DIR/"
        chown informa:informa "$TARGET_DIR/$file"
        chmod +x "$TARGET_DIR/$file"
        echo "✓ $file"
    else
        echo "✗ $file (não encontrado)"
    fi
done

echo ""
echo "Copiando templates..."
if [ -d "$SOURCE_DIR/templates" ]; then
    cp -r "$SOURCE_DIR/templates" "$TARGET_DIR/"
    chown -R informa:informa "$TARGET_DIR/templates"
    echo "✓ Templates copiados"
else
    echo "✗ Templates não encontrados"
fi

echo ""
echo "Copiando arquivos Python..."
for file in app_no_db.py; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$TARGET_DIR/"
        chown informa:informa "$TARGET_DIR/$file"
        echo "✓ $file"
    fi
done

echo ""
echo "Copiando arquivos Docker..."
for file in Dockerfile.production docker-compose.production.yml; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$TARGET_DIR/"
        chown informa:informa "$TARGET_DIR/$file"
        echo "✓ $file"
    fi
done

echo ""
echo "Verificando arquivos copiados..."
cd "$TARGET_DIR"

echo ""
echo "Arquivos no diretório:"
ls -la *.sh *.py 2>/dev/null | head -10

echo ""
echo "Testando script kiosk..."
if [ -f "simple_kiosk_enhanced.sh" ]; then
    echo "✓ simple_kiosk_enhanced.sh encontrado"
else
    echo "✗ simple_kiosk_enhanced.sh não encontrado"
fi

if [ -f "auto_update_kiosk.py" ]; then
    echo "✓ auto_update_kiosk.py encontrado"
else
    echo "✗ auto_update_kiosk.py não encontrado"
fi

echo ""
echo "=========================================="
echo "Sincronização Concluída!"
echo "=========================================="
echo ""
echo "Agora execute:"
echo "  sudo bash install_auto_update_fixed.sh"
echo ""
echo "Para testar o kiosk:"
echo "  sudo -u informa bash simple_kiosk_enhanced.sh debug"
echo ""
