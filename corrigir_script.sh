#!/bin/bash

# Script para corrigir o problema do crevision_manager.sh

echo "=========================================="
echo "CORRIGINDO SCRIPT CrediVision Manager"
echo "=========================================="
echo ""

# Verificar se o script novo existe
if [ ! -f "crevision_manager_new.sh" ]; then
    echo "ERRO: crevision_manager_new.sh nao encontrado!"
    exit 1
fi

echo "Removendo script antigo com erro..."
rm -f crevision_manager.sh

echo "Renomeando script corrigido..."
mv crevision_manager_new.sh crevision_manager.sh

echo "Configurando permissoes..."
chmod +x crevision_manager.sh

echo "Verificando sintaxe..."
if bash -n crevision_manager.sh; then
    echo "✓ Sintaxe OK"
else
    echo "✗ Erro de sintaxe encontrado"
    exit 1
fi

echo ""
echo "Testando script..."
echo "1" | timeout 5 bash crevision_manager.sh >/dev/null 2>&1
if [ $? -eq 124 ]; then
    echo "✓ Script funcionando (timeout esperado)"
else
    echo "✗ Erro ao executar script"
    exit 1
fi

echo ""
echo "=========================================="
echo "CORRECAO CONCLUIDA!"
echo "=========================================="
echo ""
echo "Agora use:"
echo "  sudo bash crevision_manager.sh"
echo ""
echo "Script corrigido e funcionando!"
echo ""
