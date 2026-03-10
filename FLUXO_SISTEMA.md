# 🔄 Fluxo Completo do Sistema CrediVision Ubuntu

## 📋 Visão Geral

Sistema kiosk para TV que inicia automaticamente com Ubuntu, gerenciado via interface web admin.

---

## 🖥️ Fluxo de Boot até Exibição

```
🔌 LIGAR COMPUTADOR
         ↓
⏰ Ubuntu Boot (15-20s)
         ↓
🚀 Systemd Services Start
├── 🔧 credvision-kiosk.service (inicia após 30s)
├── 🌐 credvision-app.service (Docker)
└── 🦊 firefox-kiosk.service
         ↓
⏱️ CONTADOR 30 SEGUNDOS (Tela de carregamento)
         ↓
🐳 Docker Inicia
├── 📁 Cria pastas ~/Documents/kiosk-*
├── 🔧 Inicia app.py (Flask)
├── 📋 Carrega JSONs (tabs, users, logs)
└── 🌐 Servidor pronto em :5000
         ↓
🦊 Firefox Kiosk Abre
├── 🖥️ Tela cheia (sem bordas)
├── 🌐 http://localhost:5000/display
└── 📺 Exibe conteúdo configurado
         ↓
🔄 ROTAÇÃO AUTOMÁTICA
├── 📋 Lê tabs.json
├── 🖼️ Exibe imagens
├── 🎥 Toca vídeos
├── 🌐 Carrega sites
└── ⏱️ Próxima aba (conforme duração)
```

---

## 📁 Estrutura de Arquivos (Persistente)

```
/home/user/Documents/
├── 📁 kiosk-data/          ← DADOS DO SISTEMA (PERSISTENTE)
│   ├── 📄 tabs.json       ← Configurações das abas
│   ├── 👥 users.json      ← Usuários do sistema
│   └── 📋 logs.json       ← Logs de auditoria
├── 📁 kiosk-media/         ← ARQUIVOS DE MÍDIA (PERSISTENTE)
│   ├── 🖼️ imagens/        ← Imagens exibidas
│   ├── 🎥 videos/         ← Vídeos exibidos
│   └── 📄 outros/         ← Outros arquivos
└── 📁 kiosk-backups/       ← BACKUPS AUTOMÁTICOS
    └── 💾 backup-*.tar.gz
```

---

## 🎮 Fluxo de Administração

```
📱 ADMINISTRADOR (via celular/computador)
         ↓
🌐 ACESSA: http://IP-DO-SERVIDOR:5000
         ↓
🔐 LOGIN: admin / admin123
         ↓
📊 DASHBOARD
├── 📈 Estatísticas (abas, usuários, logs)
├── 📋 Abas ativas
└── 🕐 Logs recentes
         ↓
⚙️ GERENCIAMENTO
├── 📺 ABAS/CONTEÚDO
│   ├── ➕ Nova Aba
│   ├── 🖼️ Upload Imagem
│   ├── 🎥 Upload Vídeo
│   ├── 🌐 Adicionar URL
│   ├── ✏️ Editar
│   ├── 🔄 Reordenar
│   └── 🗑️ Excluir
├── 👥 USUÁRIOS
│   ├── ➕ Novo Usuário
│   ├── ✏️ Editar Permissões
│   └── 🗑️ Remover
└── 📋 LOGS
    ├── 📊 Histórico completo
    └── 🔍 Filtros
         ↓
💾 SALVA AUTOMATICAMENTE
├── 📄 tabs.json atualizado
├── 📁 Arquivos salvos em ~/Documents/
└── 🔄 Kiosk atualiza em tempo real
```

---

## 🐳 Configuração Docker

### **docker-compose.yml**
```yaml
version: "3.9"
services:
  credvision-app:
    build: .
    container_name: credvision-app
    volumes:
      - /home/user/Documents/kiosk-data:/data:rw
      - /home/user/Documents/kiosk-media:/media:rw
    environment:
      - DATA_FOLDER=/data
      - MEDIA_FOLDER=/media
    ports:
      - "5000:5000"
    restart: unless-stopped
```

### **Dockerfile**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app_no_db.py"]
```

---

## 🔧 Systemd Services

### **1. credvision-app.service** (Docker)
```ini
[Unit]
Description=CrediVision Docker App
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/credvision
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### **2. credvision-kiosk.service** (Com delay)
```ini
[Unit]
Description=CrediVision Kiosk Display
After=credvision-app.service
Wants=credvision-app.service

[Service]
Type=simple
User=ubuntu
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/ubuntu/.Xauthority
ExecStart=/bin/bash -c 'sleep 30 && /usr/bin/firefox --kiosk http://localhost:5000/display'
Restart=always
RestartSec=10

[Install]
WantedBy=graphical-session.target
```

---

## ⏱️ Fluxo de 30 Segundos

### **Tela de Boot Personalizada**
```bash
# /etc/systemd/system/credvision-boot.service
[Unit]
Description=CrediVision Boot Screen
After=graphical-session.target

[Service]
Type=simple
User=ubuntu
Environment=DISPLAY=:0
ExecStart=/usr/bin/zenity --info --text="CrediVision\n\nIniciando sistema...\n\n⏱️ Aguarde 30 segundos..." --timeout=30

[Install]
WantedBy=graphical-session.target
```

### **Contador Visual**
- **0-10s**: "Iniciando serviços..."
- **10-20s**: "Carregando configurações..."
- **20-30s**: "Preparando kiosk..."
- **30s**: Firefox abre automaticamente

---

## 🔄 Ciclo de Vida

### **🔥 BOOT → EXIBIÇÃO**
```
Ligar PC → Ubuntu → Systemd → Docker → Flask → Firefox → Conteúdo
   ↓           ↓        ↓       ↓       ↓        ↓         ↓
  5s        15s      20s     25s     30s      31s      32s
```

### **📺 EXIBIÇÃO CONTÍNUA**
```
Aba 1 (15s) → Aba 2 (30s) → Aba 3 (10s) → Aba 1 → ...
     ↓              ↓              ↓              ↓
  Imagem        Site          Vídeo         Imagem
```

### **💾 PERSISTÊNCIA**
```
Desligar/Reiniciar → Arquivos mantidos em ~/Documents/
                     ↓
               Ao ligar → Lê JSONs → Continua onde parou
```

---

## 🎯 Gerenciamento de Conteúdo

### **📱 Admin Acessa**
```
Celular/PC → http://192.168.1.100:5000
     ↓
Login → Dashboard → Abas/Conteúdo
     ↓
Upload/Configura → Salva em JSON
     ↓
Kiosk atualiza → Exibe na TV
```

### **📁 Arquivos Locais**
```
Admin envia imagem → Salva em ~/Documents/kiosk-media/
                     ↓
               Kiosk lê → Exibe na TV
```

---

## 🛡️ Persistência Garantida

### **✅ O que NÃO é perdido:**
- 📄 **tabs.json** - Configurações das abas
- 👥 **users.json** - Usuários e permissões
- 📋 **logs.json** - Histórico de auditoria
- 📁 **kiosk-media/** - Todas as imagens/vídeos
- 🔧 **Configurações** - Docker e Systemd

### **🔄 O que é recriado:**
- 🐳 **Container Docker** - A cada boot
- 🦊 **Firefox** - Processo do kiosk
- 📊 **Sessões** - Login do admin

---

## 🚨 Tratamento de Erros

### **🔥 Falha no Boot**
1. **Docker não inicia**: Systemd retry
2. **App não sobe**: Restart automático
3. **Firefox falha**: Retry após 10s
4. **Arquivos corrompidos**: Restore backup

### **📺 Falha na Exibição**
1. **Aba não carrega**: Pula para próxima
2. **Arquivo ausente**: Mostra erro e continua
3. **Site offline**: Tenta novamente
4. **Rede cai**: Continua com arquivos locais

---

## 🎊 Resultado Final

### **✅ Experiência do Usuário**
1. **Ligar TV/PC** → Sistema inicia automaticamente
2. **Aguardar 30s** → Tela de carregamento informativa
3. **Kiosk abre** → Exibe conteúdo configurado
4. **Rotação contínua** → Sem intervenção manual
5. **Admin remoto** → Gerencia via celular/PC

### **✅ Experiência do Admin**
1. **Acessar interface** → Via browser qualquer dispositivo
2. **Configurar conteúdo** → Upload e URLs
3. **Monitorar status** → Dashboard em tempo real
4. **Gerenciar usuários** → Controle de acesso
5. **Ver logs** → Auditoria completa

---

**🎯 Sistema 100% Automático e Persistente!**
