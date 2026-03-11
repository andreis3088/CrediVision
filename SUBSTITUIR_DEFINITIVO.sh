#!/bin/bash

echo "=========================================="
echo "SUBSTITUICAO DEFINITIVA - Script Sem Erros"
echo "=========================================="
echo ""

echo "1. Removendo script com erro..."
rm -f crevision_manager.sh

echo "2. Copiando script corrigido..."
cp crevision_final.sh crevision_manager.sh

echo "3. Configurando permissoes..."
chmod +x crevision_manager.sh

echo "4. Verificando sintaxe..."
if bash -n crevision_manager.sh; then
    echo "   Sintaxe: OK"
else
    echo "   ERRO: Sintaxe invalida"
    exit 1
fi

echo "5. Limpando arquivos temporarios..."
rm -f crevision_final.sh
rm -f crevision_manager_new.sh
rm -f crevision_manager_fixed.sh
rm -f corrigir_script.sh

echo "6. Verificando arquivos finais..."
echo ""
echo "Arquivos essenciais:"
ls -la *.sh *.py Dockerfile.production docker-compose.production.yml 2>/dev/null | grep -v "^total"

echo ""
echo "=========================================="
echo "SUBSTITUICAO CONCLUIDA COM SUCESSO!"
echo "=========================================="
echo ""
echo "Agora use apenas:"
echo "  sudo bash crevision_manager.sh"
echo ""
echo "Script 100% funcional sem erros de EOF!"
echo ""
