#!/bin/bash

# Script para remover arquivos desnecessários do CrediVision

echo "=========================================="
echo "Limpando Arquivos Antigos"
echo "=========================================="
echo ""

# Arquivos para manter (essenciais)
KEEP_FILES=(
    "crevision_manager.sh"
    "app_no_db.py"
    "Dockerfile.production"
    "docker-compose.production.yml"
    "auto_update_kiosk.py"
    "simple_kiosk_enhanced.sh"
    "test_media.sh"
    "force_stop_all.sh"
    "requirements.txt"
)

# Diretórios para manter
KEEP_DIRS=(
    "templates"
    "__pycache__"
    ".git"
)

echo "Arquivos essenciais a manter:"
for file in "${KEEP_FILES[@]}"; do
    echo "  ✓ $file"
done
echo ""

echo "Diretórios a manter:"
for dir in "${KEEP_DIRS[@]}"; do
    echo "  ✓ $dir/"
done
echo ""

# Função para verificar se arquivo deve ser mantido
should_keep() {
    local file="$1"
    
    # Verificar se está na lista de arquivos essenciais
    for keep in "${KEEP_FILES[@]}"; do
        if [[ "$file" == "$keep" ]]; then
            return 0
        fi
    done
    
    # Verificar se é diretório essencial
    for keep_dir in "${KEEP_DIRS[@]}"; do
        if [[ "$file" == "$keep_dir" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Lista de arquivos a remover
REMOVE_FILES=()

echo "Analisando arquivos..."
for file in *; do
    if [ -f "$file" ]; then
        if ! should_keep "$file"; then
            REMOVE_FILES+=("$file")
            echo "  → Remover: $file"
        fi
    fi
done

echo ""
echo "Arquivos que serão removidos: ${#REMOVE_FILES[@]}"
if [ ${#REMOVE_FILES[@]} -gt 0 ]; then
    echo ""
    read -p "Deseja remover estes arquivos? (S/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        for file in "${REMOVE_FILES[@]}"; do
            echo "Removendo: $file"
            rm -f "$file"
        done
        echo "✓ Arquivos removidos"
    else
        echo "Cancelado."
    fi
else
    echo "Nenhum arquivo para remover."
fi

echo ""
echo "Arquivos restantes:"
ls -la
echo ""
echo "=========================================="
echo "Limpeza Concluída!"
echo "=========================================="
echo ""
echo "Agora use apenas:"
echo "  sudo bash crevision_manager.sh"
echo ""
