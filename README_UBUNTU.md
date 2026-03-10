# 🖥️ CrediVision - Guia de Instalação Ubuntu

Sistema completo de exibição automatizada em modo kiosk para TV, com suporte a imagens, vídeos e sites.

---

## 🚀 Instalação Automática (Recomendado)

### 1. Baixar o Script
```bash
wget https://seu-servidor.com/install_docker_ubuntu.sh
chmod +x install_docker_ubuntu.sh
```

### 2. Executar Instalação
```bash
sudo bash install_docker_ubuntu.sh
```

O script irá:
- ✅ Instalar Docker e Docker Compose
- ✅ Configurar Firefox Kiosk
- ✅ Criar diretórios de mídia
- ✅ Configurar serviços systemd
- ✅ Configurar firewall
- ✅ Criar scripts de backup e atualização

---

## 📁 Estrutura de Arquivos

```
/opt/credvision/
├── app.py                    # Backend Flask
├── requirements.txt          # Dependências Python
├── Dockerfile.ubuntu        # Docker para Ubuntu
├── docker-compose.ubuntu.yml # Docker Compose
├── .env                      # Variáveis ambiente
├── templates/                # Templates HTML
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── tabs.html
│   ├── users.html
│   ├── logs.html
│   └── display.html
├── install_docker_ubuntu.sh  # Script instalação
├── update.sh                 # Script atualização
└── backup.sh                 # Script backup

~/Documentos/kiosk-media/      # Arquivos de mídia
├── imagens/
├── videos/
└── outros/
```

---

## 🎯 Tipos de Conteúdo Suportados

### 🌐 Sites e URLs
- Sites completos em iframe
- Dashboards web
- Páginas HTML

### 🖼️ Imagens
- **Formatos**: PNG, JPG, JPEG, GIF
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documentos/kiosk-media/`

### 🎥 Vídeos
- **Formatos**: MP4, AVI, MOV, WEBM
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documentos/kiosk-media/`

---

## 🔧 Configuração Pós-Instalação

### 1. Acessar Sistema
```bash
# Abrir no navegador
http://IP-DO-SERVIDOR:5000
```

**Credenciais Padrão:**
- Usuário: `admin`
- Senha: `admin123`

### 2. Adicionar Conteúdo
```bash
# Copiar arquivos para pasta de mídia
cp imagem.png ~/Documentos/kiosk-media/
cp video.mp4 ~/Documentos/kiosk-media/
```

### 3. Configurar Abas
1. Acessar painel admin
2. Ir em "Abas / Conteúdo"
3. Clicar "Nova Aba"
4. Escolher tipo:
   - **URL**: Digitar endereço do site
   - **Arquivo**: Upload de imagem/vídeo

---

## 🎮 Comandos Úteis

### Gerenciamento do Serviço
```bash
# Iniciar sistema
sudo systemctl start credvision

# Parar sistema
sudo systemctl stop credvision

# Ver status
sudo systemctl status credvision

# Ver logs
sudo journalctl -u credvision -f

# Reiniciar
sudo systemctl restart credvision
```

### Docker
```bash
# Ver contêineres
docker ps

# Ver logs do contêiner
docker logs credvision-admin

# Entrar no contêiner
docker exec -it credvision-admin bash
```

### Manutenção
```bash
# Atualizar sistema
/opt/credvision/update.sh

# Fazer backup
/opt/credvision/backup.sh

# Restaurar backup
tar -xzf backup.tar.gz -C /
```

---

## 🖥️ Configuração Firefox Kiosk

### Modo Display na Mesma Máquina
```bash
# Iniciar Firefox em modo kiosk
firefox --kiosk http://localhost:5000/display

# Ou via systemd
sudo systemctl start firefox-kiosk
```

### Modo Display Remoto
```bash
# Em outra máquina com Ubuntu
export ADMIN_URL="http://IP-DO-SERVIDOR:5000"
python3 kiosk_runner.py
```

---

## 🔒 Segurança

### Trocar Senha Admin
1. Acessar: http://IP:5000/users
2. Adicionar novo usuário admin
3. Remover usuário admin padrão

### Configurar HTTPS (Opcional)
```bash
# Instalar nginx
sudo apt install nginx

# Configurar proxy reverso
# Ver nginx.conf.example
```

### Firewall
```bash
# Configurar UFW
sudo ufw allow 5000/tcp
sudo ufw allow ssh
sudo ufw enable
```

---

## 📊 Monitoramento

### Logs do Sistema
```bash
# Logs do serviço
sudo journalctl -u credvision --since "1 hour ago"

# Logs do aplicativo
docker logs credvision-admin --tail 100

# Logs de acesso
tail -f /var/log/nginx/access.log
```

### Status da API
```bash
# Ver configuração atual
curl http://localhost:5000/api/config

# Ver heartbeat
curl -X POST http://localhost:5000/api/status \
  -H "Content-Type: application/json" \
  -d '{"current_tab":"test","index":0,"total":1}'
```

---

## 🚨 Troubleshooting

### Problemas Comuns

#### 1. Servidor não inicia
```bash
# Verificar status
sudo systemctl status credvision

# Ver logs
sudo journalctl -u credvision -n 50

# Reiniciar Docker
sudo systemctl restart docker
```

#### 2. Arquivos não aparecem
```bash
# Verificar permissões
ls -la ~/Documentos/kiosk-media/

# Corrigir permissões
chmod 755 ~/Documentos/kiosk-media/
chown $USER:$USER ~/Documentos/kiosk-media/
```

#### 3. Firefox não abre
```bash
# Verificar display
echo $DISPLAY

# Instalar X11 se necessário
sudo apt install x11-utils

# Iniciar com display correto
DISPLAY=:0 firefox --kiosk http://localhost:5000/display
```

#### 4. Porta bloqueada
```bash
# Verificar portas
sudo netstat -tlnp | grep :5000

# Liberar porta no firewall
sudo ufw allow 5000/tcp
```

---

## 🔄 Atualizações

### Atualizar Sistema
```bash
# Script automático
/opt/credvision/update.sh

# Manual
cd /opt/credvision
git pull
docker compose down
docker compose build
docker compose up -d
```

### Backup Antes de Atualizar
```bash
# Criar backup
/opt/credvision/backup.sh

# Ver backups
ls -la /opt/credvision-backups/
```

---

## 📞 Suporte

### Informações do Sistema
```bash
# Coletar informações para suporte
sudo systemctl status credvision > status.log
docker logs credvision-admin > docker.log
uname -a > system.log
ip addr show > network.log

# Compactar logs
tar -czf support-$(date +%Y%m%d).tar.gz *.log
```

### Contato
- 📧 Email: suporte@credvision.com
- 📱 Telegram: @credvision-support
- 🌐 Web: https://credvision.com/support

---

## 🎉 Dicas Avançadas

### 1. Múltiplos Displays
```bash
# Configurar para múltiplas TVs
# Editar docker-compose.ubuntu.yml
# Adicionar mais serviços de display
```

### 2. Agendamento de Conteúdo
```bash
# Script para mudar conteúdo por hora
# Ver scripts/scheduler.py
```

### 3. Integração com APIs
```bash
# Consumir APIs externas
# Ver scripts/api_integration.py
```

### 4. Monitoramento Remoto
```bash
# Instalar Grafana + Prometheus
# Ver docs/monitoring.md
```

---

**🎊 Parabéns! Seu sistema CrediVision está pronto para uso!**

Para dúvidas, consulte o suporte ou a documentação completa em https://docs.credvision.com
