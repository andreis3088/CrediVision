#!/bin/bash

# Script de Inicialização - CrediVision SEM BANCO DE DADOS
# Uso: bash start_no_db.sh

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🚀 Iniciando CrediVision (SEM BANCO DE DADOS)"
echo "=========================================="

# Criar diretórios
print_header "Criando estrutura de diretórios..."
DATA_DIR="$HOME/Documents/kiosk-data"
MEDIA_DIR="$HOME/Documents/kiosk-media"

mkdir -p "$DATA_DIR"
mkdir -p "$MEDIA_DIR"

print_status "Diretórios criados:"
echo "   📁 $DATA_DIR - Dados do sistema"
echo "   📁 $MEDIA_DIR - Arquivos de mídia"

# Verificar Python
print_header "Verificando Python..."
if command -v python3 &> /dev/null; then
    print_status "Python3 encontrado"
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    print_status "Python encontrado"
    PYTHON_CMD="python"
else
    print_warning "Python não encontrado. Instalando..."
    # Adicionar instalação do Python se necessário
    exit 1
fi

# Instalar dependências
print_header "Instalando dependências Python..."
if [ -f "requirements.txt" ]; then
    $PYTHON_CMD -m pip install -r requirements.txt
    print_status "Dependências instaladas"
else
    print_warning "requirements.txt não encontrado"
fi

# Iniciar aplicação
print_header "Iniciando aplicação..."
print_status "Acessível em: http://localhost:5000"
print_status "Login: admin / admin123"
echo ""

# Iniciar servidor
$PYTHON_CMD app_no_db.py
