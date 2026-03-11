#!/bin/bash

# Script para limpeza final dos arquivos desnecessários

echo "=========================================="
echo "LIMPEZA FINAL - CrediVision"
echo "=========================================="
echo ""

# Arquivos ESSENCIAIS para manter
ESSENTIAL_FILES=(
    "crevision_manager_fixed.sh"
    "app_no_db.py"
    "Dockerfile.production"
    "docker-compose.production.yml"
    "auto_update_kiosk.py"
    "simple_kiosk_enhanced.sh"
    "test_media.sh"
    "force_stop_all.sh"
    "requirements.txt"
)

# Diretórios ESSENCIAIS para manter
ESSENTIAL_DIRS=(
    "templates"
    "__pycache__"
    ".git"
)

echo "Arquivos essenciais que serão MANTIDOS:"
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (não encontrado)"
    fi
done
echo ""

echo "Diretórios essenciais que serão MANTIDOS:"
for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir/"
    else
        echo "  ✗ $dir/ (não encontrado)"
    fi
done
echo ""

# Função para verificar se arquivo deve ser mantido
should_keep() {
    local file="$1"
    
    # Verificar se está na lista de arquivos essenciais
    for keep in "${ESSENTIAL_FILES[@]}"; do
        if [[ "$file" == "$keep" ]]; then
            return 0
        fi
    done
    
    # Verificar se é diretório essencial
    for keep_dir in "${ESSENTIAL_DIRS[@]}"; do
        if [[ "$file" == "$keep_dir" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Lista de arquivos a remover
REMOVE_FILES=()

echo "Analisando arquivos para remoção..."
for file in *; do
    if [ -f "$file" ]; then
        if ! should_keep "$file"; then
            REMOVE_FILES+=("$file")
            echo "  → Será removido: $file"
        fi
    fi
done

echo ""
echo "Total de arquivos a remover: ${#REMOVE_FILES[@]}"

if [ ${#REMOVE_FILES[@]} -gt 0 ]; then
    echo ""
    echo "Arquivos que serão removidos:"
    for file in "${REMOVE_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
    read -p "Deseja remover estes arquivos? (S/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "Removendo arquivos..."
        for file in "${REMOVE_FILES[@]}"; do
            echo "  Removendo: $file"
            rm -f "$file"
        done
        echo "✓ Arquivos removidos com sucesso"
    else
        echo "Cancelado. Nenhum arquivo removido."
    fi
else
    echo "Nenhum arquivo para remover."
fi

echo ""
echo "Renomeando script corrigido..."
if [ -f "crevision_manager_fixed.sh" ]; then
    mv crevision_manager_fixed.sh crevision_manager.sh
    echo "✓ crevision_manager.sh atualizado"
fi

echo ""
echo "Arquivos finais no diretório:"
echo "================================"
ls -la
echo ""

echo "=========================================="
echo "LIMPEZA FINAL CONCLUÍDA!"
echo "=========================================="
echo ""
echo "Agora use apenas:"
echo "  sudo bash crevision_manager.sh"
echo ""
echo "Script unificado com todas as funcionalidades!"
echo ""
