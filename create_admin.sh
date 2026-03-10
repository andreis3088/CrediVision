#!/bin/bash

# Script para Criar/Resetar Usuário Admin - CrediVision
# Uso: sudo bash create_admin.sh [nome_usuario] [senha]

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}CRIAÇÃO DE USUÁRIO ADMIN - CREDIVISION${NC} ${BLUE}$(printf "%*s" $((60 - 30)) "")${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Banner
clear
print_header

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Configurar variáveis
DEFAULT_USER="admin"
DEFAULT_PASSWORD="admin123"
DATA_DIR="/home/$SUDO_USER/Documents/kiosk-data"
USERS_FILE="$DATA_DIR/users.json"
SERVICE_USER="$SUDO_USER"

# Parâmetros de entrada
USERNAME=${1:-$DEFAULT_USER}
PASSWORD=${2:-$DEFAULT_PASSWORD}

print_status "Configuração:"
echo "   👤 Usuário: $USERNAME"
echo "   🔑 Senha: $PASSWORD"
echo "   📁 Arquivo: $USERS_FILE"
echo ""

# Verificar se o diretório de dados existe
if [ ! -d "$DATA_DIR" ]; then
    print_warning "Diretório de dados não encontrado. Criando..."
    mkdir -p "$DATA_DIR"
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR"
    chmod 755 "$DATA_DIR"
fi

# Verificar se o arquivo users.json existe
if [ ! -f "$USERS_FILE" ]; then
    print_warning "Arquivo users.json não encontrado. Criando..."
    echo "[]" > "$USERS_FILE"
    chown $SERVICE_USER:$SERVICE_USER "$USERS_FILE"
    chmod 644 "$USERS_FILE"
fi

# Função para hash de senha
hash_password() {
    local password="$1"
    echo -n "kiosk_salt_2024$password" | sha256sum | cut -d' ' -f1
}

# Verificar se Python está disponível
if ! command -v python3 &> /dev/null; then
    print_error "Python3 não encontrado. Instalando..."
    apt update && apt install -y python3
fi

# Função para criar usuário admin
create_admin_user() {
    local username="$1"
    local password="$2"
    
    print_status "Criando usuário admin: $username"
    
    # Gerar hash da senha
    local password_hash=$(hash_password "$password")
    
    # Gerar timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Criar usuário em JSON
    local new_user=$(cat << EOF
{
  "id": 1,
  "username": "$username",
  "password_hash": "$password_hash",
  "role": "admin",
  "created_at": "$timestamp"
}
EOF
)
    
    # Verificar se arquivo está vazio ou malformado
    if [ ! -s "$USERS_FILE" ]; then
        echo "[]" > "$USERS_FILE"
    fi
    
    # Usar Python para manipular JSON corretamente
    python3 << EOF
import json
import sys

# Ler arquivo atual
try:
    with open('$USERS_FILE', 'r') as f:
        users = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    users = []

# Remover usuário admin existente (se houver)
users = [u for u in users if u.get('username') != '$username']

# Adicionar novo usuário admin
new_user = {
    "id": max([u.get('id', 0) for u in users] + [0]) + 1,
    "username": "$username",
    "password_hash": "$password_hash",
    "role": "admin",
    "created_at": "$timestamp"
}
users.append(new_user)

# Salvar arquivo
with open('$USERS_FILE', 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"✅ Usuário '{username}' criado com sucesso!")
print(f"📊 Total de usuários: {len(users)}")
EOF
    
    if [ $? -eq 0 ]; then
        print_status "✅ Usuário admin criado com sucesso!"
        print_status "📊 Arquivo atualizado: $USERS_FILE"
        
        # Corrigir permissões
        chown $SERVICE_USER:$SERVICE_USER "$USERS_FILE"
        chmod 644 "$USERS_FILE"
        
        return 0
    else
        print_error "❌ Falha ao criar usuário admin"
        return 1
    fi
}

# Função para verificar usuário existente
check_existing_user() {
    local username="$1"
    
    python3 << EOF
import json

try:
    with open('$USERS_FILE', 'r') as f:
        users = json.load(f)
    
    for user in users:
        if user.get('username') == '$username':
            print(f"✅ Usuário '{username}' já existe")
            print(f"📊 Role: {user.get('role', 'unknown')}")
            print(f"📅 Criado em: {user.get('created_at', 'unknown')}")
            return True
    
    print(f"❌ Usuário '{username}' não encontrado")
    return False
    
except (FileNotFoundError, json.JSONDecodeError):
    print(f"❌ Arquivo de usuários não encontrado ou vazio")
    return False
EOF
}

# Função para resetar senha
reset_password() {
    local username="$1"
    local password="$2"
    
    print_status "Resetando senha para usuário: $username"
    
    local password_hash=$(hash_password "$password")
    
    python3 << EOF
import json

try:
    with open('$USERS_FILE', 'r') as f:
        users = json.load(f)
    
    user_found = False
    for user in users:
        if user.get('username') == '$username':
            user['password_hash'] = '$password_hash'
            user_found = True
            break
    
    if user_found:
        with open('$USERS_FILE', 'w') as f:
            json.dump(users, f, indent=2, ensure_ascii=False)
        print(f"✅ Senha do usuário '{username}' atualizada!")
    else:
        print(f"❌ Usuário '{username}' não encontrado!")
        sys.exit(1)
        
except (FileNotFoundError, json.JSONDecodeError):
    print(f"❌ Arquivo de usuários não encontrado!")
    sys.exit(1)
EOF
    
    if [ $? -eq 0 ]; then
        chown $SERVICE_USER:$SERVICE_USER "$USERS_FILE"
        print_status "✅ Senha atualizada com sucesso!"
    else
        print_error "❌ Falha ao atualizar senha"
        return 1
    fi
}

# Menu interativo
show_menu() {
    echo ""
    echo -e "${BLUE}📋 MENU DE OPÇÕES:${NC}"
    echo "1) Criar usuário admin"
    echo "2) Verificar usuário existente"
    echo "3) Resetar senha do usuário"
    echo "4) Listar todos os usuários"
    echo "5) Sair"
    echo ""
    read -p "Escolha uma opção (1-5): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            echo -e "${YELLOW}👤 CRIAR USUÁRIO ADMIN${NC}"
            echo ""
            read -p "Nome do usuário (padrão: admin): " new_username
            new_username=${new_username:-$DEFAULT_USER}
            
            read -s -p "Senha (padrão: admin123): " new_password
            echo ""
            new_password=${new_password:-$DEFAULT_PASSWORD}
            
            create_admin_user "$new_username" "$new_password"
            ;;
        2)
            echo -e "${YELLOW}🔍 VERIFICAR USUÁRIO${NC}"
            echo ""
            read -p "Nome do usuário (padrão: admin): " check_username
            check_username=${check_username:-$DEFAULT_USER}
            check_existing_user "$check_username"
            ;;
        3)
            echo -e "${YELLOW}🔑 RESETAR SENHA${NC}"
            echo ""
            read -p "Nome do usuário (padrão: admin): " reset_username
            reset_username=${reset_username:-$DEFAULT_USER}
            
            read -s -p "Nova senha (padrão: admin123): " reset_password
            echo ""
            reset_password=${reset_password:-$DEFAULT_PASSWORD}
            
            reset_password "$reset_username" "$reset_password"
            ;;
        4)
            echo -e "${YELLOW}👥 LISTAR USUÁRIOS${NC}"
            echo ""
            
            python3 << EOF
import json

try:
    with open('$USERS_FILE', 'r') as f:
        users = json.load(f)
    
    if users:
        print(f"📊 Total de usuários: {len(users)}")
        print("")
        print("┌─────┬──────────────────┬──────────────┬─────────────────────────┐")
        print("│ ID  │ Usuário           │ Role         │ Criado em               │")
        print("├─────┼──────────────────┼──────────────┼─────────────────────────┤")
        
        for user in sorted(users, key=lambda x: x.get('id', 0)):
            user_id = user.get('id', 'N/A')
            username = user.get('username', 'N/A')
            role = user.get('role', 'N/A')
            created = user.get('created_at', 'N/A')[:19] if user.get('created_at') else 'N/A'
            
            print(f"│ {user_id:<3} │ {username:<16} │ {role:<12} │ {created:<23} │")
        
        print("└─────┴──────────────────┴──────────────┴─────────────────────────┘")
    else:
        print("❌ Nenhum usuário encontrado!")
        
except (FileNotFoundError, json.JSONDecodeError):
    print("❌ Arquivo de usuários não encontrado!")
EOF
            ;;
        5)
            print -e "${GREEN}👋 Saindo...${NC}"
            exit 0
            ;;
        *)
            print -e "${RED}❌ Opção inválida!${NC}"
            show_menu
            ;;
    esac
}

# Verificar parâmetros de linha de comando
if [ $# -eq 0 ]; then
    # Modo interativo
    show_menu
else
    # Modo direto (criar usuário)
    print_status "Modo direto: criando usuário $USERNAME"
    create_admin_user "$USERNAME" "$PASSWORD"
fi

echo ""
echo -e "${GREEN}🎉 Operação concluída!${NC}"
echo ""
echo -e "${BLUE}📋 Acesso ao sistema:${NC}"
echo "   🌐 URL: http://$(hostname -I | awk '{print $1}'):5000"
echo "   👤 Usuário: $USERNAME"
echo "   🔑 Senha: $PASSWORD"
echo ""
echo -e "${YELLOW}⚠️  Lembre-se de trocar a senha após o primeiro acesso!${NC}"
