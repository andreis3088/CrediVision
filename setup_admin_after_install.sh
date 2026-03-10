#!/bin/bash

# Script Pós-Instalação - Configurar Admin CrediVision
# Executar APÓS o setup_ubuntu_kiosk.sh

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
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${YELLOW}CONFIGURAÇÃO PÓS-INSTALAÇÃO - CREDIVISION${NC} ${BLUE}$(printf "%*s" $((55 - 35)) "")${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Banner
print_header
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root (sudo)"
   exit 1
fi

# Configurar variáveis
SERVICE_USER="$SUDO_USER"
PROJECT_DIR="/opt/credvision"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"

print_status "Verificando instalação do CrediVision..."

# Verificar se o projeto foi instalado
if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Projeto CrediVision não encontrado em $PROJECT_DIR"
    echo "   Execute primeiro: sudo bash setup_ubuntu_kiosk.sh"
    exit 1
fi

# Verificar se os dados existem
if [ ! -d "$DATA_DIR" ]; then
    print_status "Criando diretório de dados..."
    mkdir -p "$DATA_DIR"
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR"
    chmod 755 "$DATA_DIR"
fi

# Verificar se o arquivo users.json existe
USERS_FILE="$DATA_DIR/users.json"
if [ ! -f "$USERS_FILE" ]; then
    print_status "Criando arquivo de usuários..."
    echo "[]" > "$USERS_FILE"
    chown $SERVICE_USER:$SERVICE_USER "$USERS_FILE"
    chmod 644 "$USERS_FILE"
fi

print_status "Configurando usuário admin padrão..."

# Usar o script create_admin.sh
if [ -f "$PROJECT_DIR/create_admin.sh" ]; then
    print_status "Executando script de criação de admin..."
    cd "$PROJECT_DIR"
    sudo -u $SERVICE_USER bash create_admin.sh admin admin123
else
    print_status "Criando usuário admin diretamente..."
    
    # Criar usuário admin manualmente
    python3 << EOF
import json
import hashlib
from datetime import datetime

# Configurações
username = "admin"
password = "admin123"
users_file = "$USERS_FILE"

# Gerar hash da senha
password_hash = hashlib.sha256(f"kiosk_salt_2024{password}".encode()).hexdigest()

# Gerar timestamp
timestamp = datetime.utcnow().isoformat() + 'Z'

# Ler usuários existentes
try:
    with open(users_file, 'r') as f:
        users = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    users = []

# Remover admin existente (se houver)
users = [u for u in users if u.get('username') != username]

# Criar novo admin
new_admin = {
    "id": max([u.get('id', 0) for u in users] + [0]) + 1,
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": timestamp
}
users.append(new_admin)

# Salvar
with open(users_file, 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"✅ Usuário admin criado!")
print(f"👤 Usuário: {username}")
print(f"🔑 Senha: {password}")
print(f"📊 Total de usuários: {len(users)}")
EOF
    
    if [ $? -eq 0 ]; then
        chown $SERVICE_USER:$SERVICE_USER "$USERS_FILE"
        chmod 644 "$USERS_FILE"
    fi
fi

# Verificar se o usuário foi criado
print_status "Verificando usuário admin..."

python3 << EOF
import json

try:
    with open('$USERS_FILE', 'r') as f:
        users = json.load(f)
    
    admin_found = False
    for user in users:
        if user.get('username') == 'admin' and user.get('role') == 'admin':
            admin_found = True
            print(f"✅ Usuário admin encontrado!")
            print(f"📊 Role: {user.get('role')}")
            print(f"📅 Criado em: {user.get('created_at')}")
            break
    
    if not admin_found:
        print("❌ Usuário admin não encontrado!")
        
except (FileNotFoundError, json.JSONDecodeError):
    print("❌ Arquivo de usuários não encontrado!")
EOF

# Verificar status dos serviços
print_status "Verificando serviços do CrediVision..."

echo ""
echo "📊 Status dos Serviços:"
systemctl is-active credvision-app && echo "   ✅ CrediVision App: Ativo" || echo "   ❌ CrediVision App: Inativo"
systemctl is-active credvision-kiosk && echo "   ✅ CrediVision Kiosk: Ativo" || echo "   ❌ CrediVision Kiosk: Inativo"
systemctl is-enabled credvision-app && echo "   ✅ CrediVision App: Habilitado" || echo "   ❌ CrediVision App: Não habilitado"
systemctl is-enabled credvision-kiosk && echo "   ✅ CrediVision Kiosk: Habilitado" || echo "   ❌ CrediVision Kiosk: Não habilitado"

# Obter IP do sistema
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Resumo final
echo ""
print_header "🎉 CONFIGURAÇÃO CONCLUÍDA!"
echo ""
echo -e "${GREEN}✅ Usuário admin configurado com sucesso!${NC}"
echo ""
echo -e "${BLUE}📋 ACESSO AO SISTEMA:${NC}"
echo "   🌐 Interface Admin: http://$IP_ADDRESS:5000"
echo "   📺 Display Kiosk: http://$IP_ADDRESS:5000/display"
echo ""
echo -e "${BLUE}👤 CREDENCIAIS:${NC}"
echo "   👤 Usuário: admin"
echo "   🔑 Senha: admin123"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo "   🔐 Troque a senha padrão após primeiro acesso"
echo "   📱 Acesse de qualquer dispositivo na rede"
echo "   📺 O kiosk abrirá automaticamente na TV"
echo ""
echo -e "${BLUE}🔧 COMANDOS ÚTEIS:${NC}"
echo "   📊 Status: sudo systemctl status credvision-app"
echo "   📋 Logs: sudo journalctl -u credvision-app -f"
echo "   🔍 Diagnóstico: sudo $PROJECT_DIR/diagnose_kiosk.sh"
echo "   👥 Gerenciar usuários: sudo $PROJECT_DIR/create_admin.sh"
echo ""
echo -e "${BLUE}📁 ESTRUTURA DE DADOS:${NC}"
echo "   📄 $DATA_DIR/tabs.json - Configurações das abas"
echo "   👥 $DATA_DIR/users.json - Usuários do sistema"
echo "   📋 $DATA_DIR/logs.json - Logs de auditoria"
echo "   📁 $HOME/Documents/kiosk-media/ - Arquivos de mídia"
echo ""
echo -e "${GREEN}🎊 Sistema pronto para uso!${NC}"
echo -e "${GREEN}📺 A TV exibirá o conteúdo automaticamente!${NC}"

# Perguntar se quer iniciar os serviços agora
echo ""
read -p "Deseja iniciar os serviços do CrediVision agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_status "Iniciando serviços..."
    systemctl start credvision-app
    sleep 5
    systemctl start credvision-kiosk
    print_status "✅ Serviços iniciados!"
else
    print_status "Para iniciar manualmente:"
    echo "   sudo systemctl start credvision-app"
    echo "   sudo systemctl start credvision-kiosk"
fi

echo ""
print_status "🎉 Configuração pós-instalação concluída!"
