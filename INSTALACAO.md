# Sistema Kiosk CrediVision - Guia de Instalação

## Índice

1. [Visão Geral](#visão-geral)
2. [Requisitos do Sistema](#requisitos-do-sistema)
3. [Pré-Instalação](#pré-instalação)
4. [Instalação Automatizada](#instalação-automatizada)
5. [Instalação Manual](#instalação-manual)
6. [Configuração Pós-Instalação](#configuração-pós-instalação)
7. [Verificação](#verificação)
8. [Solução de Problemas](#solução-de-problemas)

## Visão Geral

O CrediVision é um sistema kiosk projetado para exibir conteúdo rotativo (URLs, imagens, vídeos) em uma TV ou monitor. O sistema consiste em:

- Aplicação web Flask para administração
- Container Docker para isolamento da aplicação
- Firefox em modo kiosk para exibição de conteúdo
- Armazenamento baseado em arquivos na pasta Documentos
- Serviços systemd para inicialização automática

## Requisitos do Sistema

### Requisitos de Hardware

- CPU: 2 núcleos mínimo (4+ recomendado)
- RAM: 4GB mínimo (8GB+ recomendado)
- Armazenamento: 20GB de espaço livre mínimo
- Rede: Conexão Ethernet ou WiFi
- Display: Monitor ou TV compatível com HDMI

### Requisitos de Software

- Sistema Operacional: Ubuntu 20.04 LTS ou mais recente (edição Desktop)
- Conta de usuário com privilégios sudo
- Conexão com internet para configuração inicial

### Requisitos de Rede

- Porta 5000 deve estar disponível para a interface web
- Acesso à internet para download de imagens Docker
- Acesso à rede local para administração remota

## Pré-Instalação

### Passo 1: Atualizar Sistema

Antes da instalação, certifique-se de que seu sistema está atualizado:

```bash
sudo apt update
sudo apt upgrade -y
```

### Passo 2: Clonar Repositório

Clone o repositório CrediVision para seu sistema:

```bash
cd ~
git clone https://github.com/SEU-USUARIO/credivision.git
cd credivision
```

Se você já tem o repositório clonado, navegue até o diretório do projeto:

```bash
cd /caminho/para/credivision
```

### Passo 3: Verificar Arquivos

Certifique-se de que todos os arquivos necessários estão presentes:

```bash
ls -la
```

Arquivos necessários:
- install.sh (script de instalação)
- manage.sh (script de gerenciamento)
- app_no_db.py (backend da aplicação)
- Dockerfile.production (configuração Docker)
- requirements.txt (dependências Python)
- templates/ (diretório de templates HTML)

## Instalação Automatizada

O script de instalação automatizada cuida de todas as tarefas de configuração.

### Passo 1: Tornar Script Executável

```bash
chmod +x install.sh
```

### Passo 2: Executar Script de Instalação

Execute o script de instalação com sudo:

```bash
sudo bash install.sh
```

### Passo 3: Monitorar Instalação

O script executará as seguintes tarefas:

1. Atualizar pacotes do sistema
2. Instalar dependências do sistema
3. Instalar Docker e Docker Compose
4. Criar estrutura de diretórios
5. Configurar variáveis de ambiente
6. Criar configuração Docker Compose
7. Criar serviços systemd
8. Construir imagem Docker
9. Iniciar serviços
10. Criar usuário admin padrão
11. Configurar firewall

A instalação normalmente leva 10-15 minutos dependendo da velocidade da internet.

### Passo 4: Reiniciar Sistema

Após a conclusão da instalação, reinicie o sistema:

```bash
sudo reboot
```

O sistema iniciará automaticamente o kiosk no boot.

## Instalação Manual

Se você preferir instalação manual ou o script automatizado falhar, siga estes passos.

### Passo 1: Instalar Dependências do Sistema

```bash
sudo apt update
sudo apt install -y \
    curl wget git unzip htop nano vim \
    python3 python3-pip python3-venv build-essential \
    firefox zenity x11-utils x11-xserver-utils net-tools \
    ca-certificates gnupg lsb-release
```

### Passo 2: Instalar Docker

Remover versões antigas do Docker:

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
```

Adicionar repositório Docker:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Instalar Docker:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Configurar Docker:

```bash
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
```

Faça logout e login novamente para que as alterações de grupo tenham efeito.

### Passo 3: Criar Estrutura de Diretórios

```bash
mkdir -p ~/Documents/kiosk-data
mkdir -p ~/Documents/kiosk-media/images
mkdir -p ~/Documents/kiosk-media/videos
mkdir -p ~/Documents/kiosk-backups

echo "[]" > ~/Documents/kiosk-data/tabs.json
echo "[]" > ~/Documents/kiosk-data/users.json
echo "[]" > ~/Documents/kiosk-data/logs.json

chmod 755 ~/Documents/kiosk-data
chmod 755 ~/Documents/kiosk-media
```

### Passo 4: Configurar Ambiente

Criar arquivo .env no diretório do projeto:

```bash
cd /caminho/para/credivision

cat > .env << 'EOF'
SECRET_KEY=$(openssl rand -hex 32)
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
FLASK_ENV=production
APP_PORT=5000
SESSION_TIMEOUT=3600
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900
MAX_FILE_SIZE=104857600
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,mp4,avi,mov,webm
TABS_FILE=/data/tabs.json
USERS_FILE=/data/users.json
LOGS_FILE=/data/logs.json
EOF

chmod 600 .env
```

### Passo 5: Criar Configuração Docker Compose

Criar docker-compose.yml:

```bash
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  credivision-app:
    build:
      context: .
      dockerfile: Dockerfile.production
    container_name: credivision-app
    environment:
      - DATA_FOLDER=/data
      - MEDIA_FOLDER=/media
      - SECRET_KEY=${SECRET_KEY}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - FLASK_ENV=production
    ports:
      - "5000:5000"
    volumes:
      - ~/Documents/kiosk-data:/data:rw
      - ~/Documents/kiosk-media:/media:rw
    restart: unless-stopped
    networks:
      - credivision-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/config"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  credivision-net:
    driver: bridge
EOF
```

### Passo 6: Construir Imagem Docker

```bash
docker build -f Dockerfile.production -t credivision-app .
```

### Passo 7: Criar Serviços Systemd

Criar serviço da aplicação:

```bash
sudo tee /etc/systemd/system/credivision-app.service > /dev/null << 'EOF'
[Unit]
Description=Aplicação Kiosk CrediVision
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/caminho/para/credivision
User=SEU_USUARIO
Group=SEU_USUARIO
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
```

Substitua /caminho/para/credivision e SEU_USUARIO pelos valores reais.

Criar serviço do kiosk:

```bash
sudo tee /etc/systemd/system/credivision-kiosk.service > /dev/null << 'EOF'
[Unit]
Description=Display Kiosk Firefox CrediVision
After=credivision-app.service graphical.target
Wants=credivision-app.service

[Service]
Type=simple
User=SEU_USUARIO
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/SEU_USUARIO/.Xauthority
ExecStartPre=/bin/sleep 30
ExecStart=/usr/bin/firefox --kiosk http://localhost:5000/display --no-first-run --disable-pinch --disable-infobars
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF
```

Substitua SEU_USUARIO pelo nome de usuário real.

### Passo 8: Habilitar Serviços

```bash
sudo systemctl daemon-reload
sudo systemctl enable credivision-app.service
sudo systemctl enable credivision-kiosk.service
```

### Passo 9: Iniciar Serviços

```bash
sudo systemctl start credivision-app.service
```

Aguarde 30 segundos para a aplicação iniciar, então:

```bash
sudo systemctl start credivision-kiosk.service
```

### Passo 10: Criar Usuário Admin

```bash
python3 << 'EOF'
import json
import hashlib
from datetime import datetime

username = "admin"
password = "admin123"
users_file = "/home/SEU_USUARIO/Documents/kiosk-data/users.json"

password_hash = hashlib.sha256(f"kiosk_salt_2024{password}".encode()).hexdigest()
timestamp = datetime.utcnow().isoformat() + 'Z'

users = []
new_admin = {
    "id": 1,
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": timestamp
}
users.append(new_admin)

with open(users_file, 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"Usuário admin criado: {username}")
EOF
```

Substitua SEU_USUARIO pelo nome de usuário real.

## Configuração Pós-Instalação

### Acessar Interface Admin

1. Abra um navegador web em qualquer dispositivo na mesma rede
2. Navegue para: http://IP_DO_SERVIDOR:5000
3. Faça login com as credenciais:
   - Usuário: admin
   - Senha: admin123

### Alterar Senha Padrão

IMPORTANTE: Altere a senha padrão imediatamente.

1. Faça login na interface admin
2. Navegue para seção Usuários
3. Edite usuário admin
4. Defina uma senha forte
5. Salve as alterações

### Configurar Primeira Aba

1. Navegue para seção Abas/Conteúdo
2. Clique em "Nova Aba"
3. Escolha o tipo de conteúdo:
   - URL: Digite o endereço do site
   - Imagem: Faça upload de arquivo de imagem (PNG, JPG, GIF)
   - Vídeo: Faça upload de arquivo de vídeo (MP4, AVI, MOV, WEBM)
4. Defina duração de exibição (em segundos)
5. Salve a aba

### Configurar Auto-Login (Opcional)

Para inicialização automática do kiosk sem login manual:

Edite configuração GDM:

```bash
sudo nano /etc/gdm3/custom.conf
```

Adicione sob [daemon]:

```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=SEU_USUARIO
```

Substitua SEU_USUARIO pelo nome de usuário real.

Reinicie GDM:

```bash
sudo systemctl restart gdm3
```

## Verificação

### Verificar Serviços

Verificar status dos serviços:

```bash
sudo systemctl status credivision-app.service
sudo systemctl status credivision-kiosk.service
```

Ambos devem mostrar "active (running)".

### Verificar Container Docker

```bash
docker ps
```

Deve mostrar o container credivision-app em execução.

### Verificar API

```bash
curl http://localhost:5000/api/config
```

Deve retornar resposta JSON com configuração de abas.

### Verificar Display Kiosk

O Firefox deve estar executando em modo tela cheia exibindo a interface do kiosk.

Verificar processo Firefox:

```bash
ps aux | grep firefox | grep kiosk
```

### Verificar Armazenamento de Arquivos

Verificar arquivos de dados:

```bash
ls -la ~/Documents/kiosk-data/
```

Deve mostrar tabs.json, users.json, logs.json.

Verificar diretório de mídia:

```bash
ls -la ~/Documents/kiosk-media/
```

Deve mostrar subdiretórios images/ e videos/.

## Solução de Problemas

### Script de Instalação Falha

Se a instalação automatizada falhar:

1. Verifique mensagens de erro na saída do terminal
2. Verifique conexão com internet
3. Certifique-se de ter espaço suficiente em disco: `df -h`
4. Verifique logs do sistema: `sudo journalctl -xe`
5. Tente os passos de instalação manual

### Build do Docker Falha

Se a construção da imagem Docker falhar:

1. Verifique se Docker está em execução: `sudo systemctl status docker`
2. Verifique se Dockerfile.production existe
3. Verifique se requirements.txt está presente
4. Revise logs de build para erros específicos
5. Tente construir manualmente: `docker build -f Dockerfile.production -t credivision-app .`

### Serviços Não Iniciam

Se os serviços systemd falharem ao iniciar:

1. Verifique status do serviço: `sudo systemctl status credivision-app.service`
2. Veja logs do serviço: `sudo journalctl -u credivision-app.service -n 50`
3. Verifique container Docker: `docker ps -a`
4. Verifique logs do container: `docker logs credivision-app`
5. Verifique permissões de arquivo no diretório do projeto

### Kiosk Não Exibe

Se o kiosk Firefox não iniciar:

1. Verifique variável DISPLAY: `echo $DISPLAY`
2. Verifique se servidor X está em execução: `ps aux | grep Xorg`
3. Verifique serviço kiosk: `sudo systemctl status credivision-kiosk.service`
4. Veja logs do kiosk: `sudo journalctl -u credivision-kiosk.service -n 50`
5. Teste Firefox manualmente: `DISPLAY=:0 firefox --kiosk http://localhost:5000/display`

### API Não Responde

Se a API não responder:

1. Verifique se container está em execução: `docker ps`
2. Verifique se porta está escutando: `netstat -tlnp | grep 5000`
3. Teste localmente: `curl http://localhost:5000/api/config`
4. Verifique logs do container: `docker logs credivision-app`
5. Verifique regras de firewall: `sudo ufw status`

### Erros de Permissão

Se encontrar erros de permissão:

1. Verifique propriedade do diretório:
   ```bash
   sudo chown -R $USER:$USER ~/Documents/kiosk-data
   sudo chown -R $USER:$USER ~/Documents/kiosk-media
   ```

2. Defina permissões corretas:
   ```bash
   chmod 755 ~/Documents/kiosk-data
   chmod 755 ~/Documents/kiosk-media
   ```

3. Verifique associação ao grupo Docker:
   ```bash
   groups $USER
   ```
   Deve incluir grupo "docker".

### Porta Já em Uso

Se a porta 5000 já estiver em uso:

1. Encontre processo usando a porta:
   ```bash
   sudo netstat -tlnp | grep 5000
   ```

2. Pare o processo conflitante ou altere a porta do CrediVision em docker-compose.yml

### Para Ajuda Adicional

1. Verifique diagnóstico do sistema: `sudo bash manage.sh diagnose`
2. Revise logs da aplicação: `sudo bash manage.sh logs`
3. Revise logs do kiosk: `sudo bash manage.sh logs-kiosk`
4. Consulte OPERACAO.md para procedimentos operacionais
5. Verifique issues no GitHub para problemas conhecidos

## Próximos Passos

Após instalação bem-sucedida:

1. Leia OPERACAO.md para procedimentos de operação diária
2. Configure cronograma de backup
3. Configure rotação de conteúdo
4. Teste reinicialização do sistema para verificar auto-inicialização
5. Documente sua configuração específica

## Recomendações de Segurança

1. Altere senha padrão do admin imediatamente
2. Use senhas fortes para todos os usuários
3. Mantenha sistema atualizado: `sudo apt update && sudo apt upgrade`
4. Limite acesso de rede à interface admin
5. Backups regulares: `sudo bash manage.sh backup`
6. Monitore logs para atividade suspeita
7. Desabilite serviços não utilizados
8. Use firewall para restringir acesso

## Suporte

Para problemas não cobertos neste guia:

- Revise OPERACAO.md para procedimentos operacionais
- Verifique manage.sh para comandos de gerenciamento
- Revise logs do sistema para mensagens de erro
- Consulte documentação do projeto
- Reporte bugs na página de issues do GitHub
