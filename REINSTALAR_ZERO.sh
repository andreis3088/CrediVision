#!/bin/bash

echo "=========================================="
echo "REINSTALAÇÃO COMPLETA DO ZERO - CrediVision"
echo "=========================================="
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash REINSTALAR_ZERO.sh"
    exit 1
fi

# Obter usuário atual
CURRENT_USER=${SUDO_USER:-$USER}
echo "Usuário atual: $CURRENT_USER"
echo ""

# Diretório do projeto
PROJECT_DIR="/home/$CURRENT_USER/Documentos/CrediVision"
echo "Diretório do projeto: $PROJECT_DIR"
echo ""

echo "⚠️  AVISO: Isso vai REMOVER TUDO do CrediVision!"
echo "   - Containers Docker"
echo "   - Imagens Docker"
echo "   - Serviços systemd"
echo "   - Arquivos de dados"
echo "   - Backups"
echo ""
read -p "Tem certeza? (digite 'SIM' para continuar): " CONFIRM

if [ "$CONFIRM" != "SIM" ]; then
    echo "Cancelado."
    exit 1
fi

echo ""
echo "=========================================="
echo "PASSO 1: Parando e Removendo Serviços"
echo "=========================================="

# Parar serviços systemd
echo "Parando serviços systemd..."
systemctl stop credivision-kiosk.service 2>/dev/null || true
systemctl stop credivision-app.service 2>/dev/null || true
systemctl stop credivision-backup.service 2>/dev/null || true
systemctl stop credivision-backup.timer 2>/dev/null || true

# Desabilitar serviços
echo "Desabilitando serviços..."
systemctl disable credivision-kiosk.service 2>/dev/null || true
systemctl disable credivision-app.service 2>/dev/null || true
systemctl disable credivision-backup.service 2>/dev/null || true
systemctl disable credivision-backup.timer 2>/dev/null || true

# Remover arquivos de serviços
echo "Removendo arquivos de serviços..."
rm -f /etc/systemd/system/credivision-*.service
rm -f /etc/systemd/system/credivision-*.timer
systemctl daemon-reload

echo ""
echo "=========================================="
echo "PASSO 2: Removendo Containers e Imagens Docker"
echo "=========================================="

# Parar todos os containers
echo "Parando containers..."
docker stop $(docker ps -q) 2>/dev/null || true

# Remover containers do CrediVision
echo "Removendo containers..."
docker rm -f credivision-app 2>/dev/null || true
docker compose down 2>/dev/null || true

# Remover imagens do CrediVision
echo "Removendo imagens..."
docker rmi -f credivision-app 2>/dev/null || true
docker rmi $(docker images -q credivision-app) 2>/dev/null || true

# Limpar cache do Docker
echo "Limpando cache do Docker..."
docker builder prune -a -f
docker system prune -a -f --volumes

echo ""
echo "=========================================="
echo "PASSO 3: Removendo Arquivos do Sistema"
echo "=========================================="

# Remover diretórios de dados
echo "Removendo diretórios de dados..."
rm -rf /home/$CURRENT_USER/Documents/kiosk-data
rm -rf /home/$CURRENT_USER/Documents/kiosk-media
rm -rf /home/$CURRENT_USER/Documents/kiosk-backups

# Remover diretório do projeto (backup primeiro)
echo "Fazendo backup do diretório do projeto..."
if [ -d "$PROJECT_DIR" ]; then
    mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    echo "Diretório original movido para backup"
fi

echo ""
echo "=========================================="
echo "PASSO 4: Verificando Remoção"
echo "=========================================="

echo "Verificando se tudo foi removido..."

# Verificar serviços
echo "Serviços systemd:"
systemctl list-units | grep credivision || echo "✓ Nenhum serviço credivision encontrado"

# Verificar containers
echo "Containers Docker:"
docker ps -a | grep credivision || echo "✓ Nenhum container credivision encontrado"

# Verificar imagens
echo "Imagens Docker:"
docker images | grep credivision || echo "✓ Nenhuma imagem credivision encontrada"

# Verificar diretórios
echo "Diretórios de dados:"
if [ -d "/home/$CURRENT_USER/Documents/kiosk-data" ]; then
    echo "❌ kiosk-data ainda existe"
else
    echo "✓ kiosk-data removido"
fi

if [ -d "/home/$CURRENT_USER/Documents/kiosk-media" ]; then
    echo "❌ kiosk-media ainda existe"
else
    echo "✓ kiosk-media removido"
fi

if [ -d "/home/$CURRENT_USER/Documents/kiosk-backups" ]; then
    echo "❌ kiosk-backups ainda existe"
else
    echo "✓ kiosk-backups removido"
fi

echo ""
echo "=========================================="
echo "PASSO 5: Reinstalação do Zero"
echo "=========================================="

echo "Iniciando reinstalação completa..."

# Criar diretório do projeto
echo "Criando diretório do projeto..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Clonar repositório (se estiver usando git)
echo "Clonando repositório..."
if [ -d "/home/$CURRENT_USER/Documentos/CrediVision_backup_"* ]; then
    echo "Copiando do backup local..."
    cp -r /home/$CURRENT_USER/Documentos/CrediVision_backup_*/templates .
    cp -r /home/$CURRENT_USER/Documentos/CrediVision_backup_*/static .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/*.py .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/requirements.txt .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/Dockerfile.production .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/docker-compose.production.yml .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/install.sh .
    cp /home/$CURRENT_USER/Documentos/CrediVision_backup_*/manage.sh .
else
    echo "ERRO: Nenhum backup encontrado!"
    echo "Você precisa clonar o repositório manualmente:"
    echo "git clone https://github.com/SEU-USUARIO/credivision.git $PROJECT_DIR"
    exit 1
fi

# Corrigir permissões
echo "Corrigindo permissões..."
chown -R $CURRENT_USER:$CURRENT_USER "$PROJECT_DIR"
chmod +x "$PROJECT_DIR/install.sh"
chmod +x "$PROJECT_DIR/manage.sh"

echo ""
echo "=========================================="
echo "PASSO 6: Executando Instalação"
echo "=========================================="

echo "Executando script de instalação..."
echo "Isso levará 10-15 minutos..."
echo ""

# Executar instalação
su - $CURRENT_USER -c "cd $PROJECT_DIR && sudo bash install.sh"

echo ""
echo "=========================================="
echo "REINSTALAÇÃO CONCLUÍDA!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. Após reiniciar, acesse: http://$(hostname -I | awk '{print $1}'):5000"
echo "3. Faça login com: admin / admin123"
echo "4. Troque a senha padrão imediatamente!"
echo ""
echo "Comandos úteis:"
echo "  Ver status: sudo bash manage.sh status"
echo "  Ver logs: sudo bash manage.sh logs"
echo "  Diagnóstico: sudo bash manage.sh diagnose"
echo ""
echo "Se algo der errado, verifique:"
echo "  - Docker está instalado e rodando: docker --version"
echo "  - Serviços systemd: systemctl status credivision-app.service"
echo "  - Container: docker ps | grep credivision-app"
echo ""
