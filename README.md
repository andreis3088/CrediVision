# 🖥️ Sistema Kiosk — Guia Completo

Sistema de exibição automatizada em modo kiosk para TV, com interface administrativa remota.

---

## 📁 Estrutura do Projeto

```
kiosk-system/
├── app/
│   ├── app.py                  # Backend Flask principal
│   ├── requirements.txt
│   └── templates/
│       ├── base.html           # Layout base (sidebar + topbar)
│       ├── login.html          # Tela de login
│       ├── dashboard.html      # Dashboard principal
│       ├── tabs.html           # Gerenciamento de abas
│       ├── users.html          # Gerenciamento de usuários
│       ├── logs.html           # Logs de auditoria
│       └── display.html        # Tela exibida na TV (kiosk)
├── scripts/
│   └── kiosk_runner.py         # Automação do Firefox kiosk
└── docker/
    ├── Dockerfile
    ├── docker-compose.yml
    └── entrypoint.sh
```

---

## 🚀 Início Rápido

### Opção A — Docker (Recomendado)

```bash
# 1. Clone / extraia o projeto
cd kiosk-system

# 2. Configure variáveis de ambiente
cp .env.example .env
nano .env   # edite SECRET_KEY e ADMIN_PASSWORD

# 3. Suba os contêineres
cd docker
docker compose up -d

# 4. Acesse a interface admin
# http://<IP_DO_SERVIDOR>:5000
```

### Opção B — Instalação Direta (Ubuntu)

```bash
# Instale dependências Python
pip3 install flask flask-login selenium gunicorn

# Inicie o servidor admin
cd app
python3 app.py

# Em outro terminal, inicie o kiosk (com Firefox instalado)
python3 ../scripts/kiosk_runner.py
```

---

## 🔐 Credenciais Padrão

| Usuário | Senha    | Nível  |
|---------|----------|--------|
| admin   | admin123 | Admin  |

> ⚠️ **Troque a senha após o primeiro acesso!**

---

## 🎛️ Interface Administrativa

### Rotas disponíveis

| Rota | Descrição | Acesso |
|------|-----------|--------|
| `/dashboard` | Visão geral do sistema | Todos |
| `/tabs` | Gerenciar abas exibidas | Todos |
| `/users` | Criar/remover usuários | Admin |
| `/logs` | Histórico de ações | Admin |
| `/display` | Tela da TV (preview) | Público |
| `/api/config` | JSON com configuração | Público |

---

## 🎨 Paleta de Cores

| Cor | Hex | Uso |
|-----|-----|-----|
| Turquesa | `#00AE9D` | Primária, navbar, botões |
| Verde Escuro | `#003641` | Background, texto |
| Branco | `#FFFFFF` | Fundos, texto em contraste |
| Verde Claro | `#C9D200` | Alertas de sucesso |
| Verde Médio | `#7DB61C` | Badges ativas |
| Roxo | `#49479D` | Acento secundário |

---

## ⚙️ Variáveis de Ambiente

```env
SECRET_KEY=chave-secreta-aleatoria-longa
ADMIN_PASSWORD=sua-senha-segura
DB_PATH=/data/kiosk.db
ADMIN_URL=http://localhost:5000
KIOSK_MODE=full        # full | admin-only | display-only
CONFIG_REFRESH=300     # segundos entre refreshes de config
DISPLAY=:0             # display X11
```

---

## 🐋 Docker — Modos de Operação

### `admin-only`
Apenas a interface Flask. Ideal para rodar em servidor separado.

```bash
KIOSK_MODE=admin-only docker compose up kiosk-admin
```

### `display-only`
Apenas o Firefox kiosk, busca config do admin remoto.

```bash
KIOSK_MODE=display-only ADMIN_URL=http://192.168.1.10:5000 docker compose up kiosk-display
```

### `full` (padrão)
Admin + display na mesma máquina.

---

## 📺 Configuração na TV

### Autostart no Ubuntu (systemd)

```ini
# /etc/systemd/system/kiosk.service
[Unit]
Description=Sistema Kiosk
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=/opt/kiosk-system/docker
ExecStart=docker compose up
ExecStop=docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable kiosk
sudo systemctl start kiosk
```

---

## 🔌 API

### `GET /api/config`
Retorna as abas ativas em JSON.

```json
{
  "tabs": [
    {"id": 1, "name": "Dashboard", "url": "http://...", "duration": 300}
  ],
  "updated_at": "2024-01-15T14:30:00"
}
```

### `POST /api/status`
Recebe heartbeat do kiosk com a aba atual.

```json
{"current_tab": "Dashboard", "index": 0, "total": 3}
```

---

## 🔧 Manutenção

```bash
# Ver logs
docker compose logs -f kiosk-admin

# Backup do banco de dados
docker cp kiosk-admin:/data/kiosk.db ./backup-$(date +%Y%m%d).db

# Atualizar sem downtime
docker compose pull && docker compose up -d --no-deps kiosk-admin
```

---

## 🔒 Segurança

- Autenticação com hash SHA-256 + salt
- Sessões Flask com chave secreta rotacionável
- RBAC: Admin (acesso total) / Viewer (somente leitura)
- Logs de auditoria completos (IP, usuário, ação)
- Para produção: configure HTTPS com nginx reverse proxy

### Exemplo nginx + SSL

```nginx
server {
    listen 443 ssl;
    server_name kiosk.empresa.local;

    ssl_certificate     /etc/ssl/kiosk.crt;
    ssl_certificate_key /etc/ssl/kiosk.key;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
