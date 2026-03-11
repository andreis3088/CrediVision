#!/bin/bash

# Script para continuar a instalacao do CrediVision

echo "=========================================="
echo "CONTINUAR INSTALACAO - CrediVision"
echo "=========================================="
echo ""

# Verificar se esta rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "ERRO: Execute este script com sudo"
    echo "Uso: sudo bash continuar_instalacao.sh"
    exit 1
fi

SERVICE_USER="informa"
PROJECT_DIR="/home/$SERVICE_USER/Documentos/CrediVision"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"

echo "Usuario: $SERVICE_USER"
echo "Projeto: $PROJECT_DIR"
echo ""

# Verificar se o diretorio do projeto existe
if [ ! -d "$PROJECT_DIR" ]; then
    echo "ERRO: Diretorio do projeto nao encontrado: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

echo "PASSO 1: Instalando pacotes restantes..."
echo ""

# Instalar pacote de notificacao correto
echo "Instalando libnotify-bin (notificacoes)..."
apt install -y libnotify-bin

# Verificar outros pacotes necessarios
echo "Verificando pacotes adicionais..."
apt install -y python3-pip

echo ""
echo "PASSO 2: Instalando Python watchdog..."
pip3 install watchdog

echo ""
echo "PASSO 3: Criando diretorios..."
mkdir -p "$DATA_DIR"
mkdir -p "$MEDIA_DIR/images"
mkdir -p "$MEDIA_DIR/videos"
mkdir -p "$BACKUP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
echo "Diretorios criados"

echo ""
echo "PASSO 4: Criando dados iniciais..."
cat > "$DATA_DIR/tabs.json" << 'EOF'
[]
EOF

cat > "$DATA_DIR/users.json" << 'EOF'
[
  {
    "id": 1,
    "username": "admin",
    "password_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "role": "admin",
    "created_at": "2024-01-01T00:00:00"
  }
]
EOF

cat > "$DATA_DIR/logs.json" << 'EOF'
[]
EOF

chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"/*.json
echo "Dados iniciais criados"

echo ""
echo "PASSO 5: Construindo imagem Docker (SEM CACHE)..."
docker rmi -f credivision-app 2>/dev/null || true
docker builder prune -a -f
docker system prune -f

echo "Construindo imagem (pode demorar 5-10 minutos)..."
if docker build --no-cache --pull -f Dockerfile.production -t credivision-app .; then
    echo "Imagem Docker construida com sucesso"
else
    echo "ERRO: Falha ao construir imagem Docker"
    exit 1
fi

echo ""
echo "PASSO 6: Criando servicos systemd..."

# App service
cat > /etc/systemd/system/credivision-app.service << EOF
[Unit]
Description=CrediVision Flask Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Environment=DATA_FOLDER=$DATA_DIR
Environment=MEDIA_FOLDER=$MEDIA_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Kiosk service
cat > /etc/systemd/system/credivision-kiosk.service << EOF
[Unit]
Description=CrediVision Simple Kiosk
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStartPre=/bin/sleep 30
ExecStart=$PROJECT_DIR/simple_kiosk_enhanced.sh fullscreen
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Auto-update service
cat > /etc/systemd/system/credivision-auto-update.service << EOF
[Unit]
Description=CrediVision Auto Update Service
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStart=/usr/bin/python3 $PROJECT_DIR/auto_update_kiosk.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Backup service
cat > /etc/systemd/system/credivision-backup.service << EOF
[Unit]
Description=CrediVision Backup Service

[Service]
Type=oneshot
User=$SERVICE_USER
ExecStart=$PROJECT_DIR/crevision_manager.sh backup-silent

[Install]
WantedBy=multi-user.target
EOF

# Backup timer
cat > /etc/systemd/system/credivision-backup.timer << EOF
[Unit]
Description=Run CrediVision backup daily
Requires=credivision-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable credivision-app.service
systemctl enable credivision-kiosk.service
systemctl enable credivision-auto-update.service
systemctl enable credivision-backup.timer

echo "Servicos criados e habilitados"

echo ""
echo "PASSO 7: Configurando permissoes e firewall..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
chmod +x "$PROJECT_DIR"/*.sh
usermod -a -G input "$SERVICE_USER"
usermod -a -G video "$SERVICE_USER"

apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5000/tcp
ufw --force enable

echo "Permissoes e firewall configurados"

echo ""
echo "PASSO 8: Testando instalacao..."
systemctl start credivision-app.service
sleep 10

if curl -s http://localhost:5000/api/config > /dev/null; then
    echo "API respondendo - OK"
else
    echo "ERRO: API nao respondendo"
    echo "Verificando logs:"
    docker logs credivision-app 2>/dev/null | tail -10
    exit 1
fi

echo ""
echo "=========================================="
echo "INSTALACAO CONCLUIDA COM SUCESSO!"
echo "=========================================="
echo ""
echo "Informacoes do Sistema:"
echo "  URL: http://$(hostname -I | awk '{print $1}'):5000"
echo "  Login: admin / admin123"
echo "  Dados: $DATA_DIR"
echo "  Midia: $MEDIA_DIR"
echo ""
echo "Proximos Passos:"
echo "  1. Reinicie o sistema: sudo reboot"
echo "  2. Aguarde 2-3 minutos"
echo "  3. Acesse a interface web"
echo "  4. TROQUE A SENHA PADRAO!"
echo "  5. Adicione seu conteudo"
echo ""
echo "Comandos Uteis:"
echo "  Gerenciar: sudo bash crevision_manager.sh"
echo "  Status: sudo bash crevision_manager.sh (opcao 4.1)"
echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
echo ""
echo "IMPORTANTE: Troque a senha do admin imediatamente!"
echo ""
