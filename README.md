# 🖥️ CrediVision - Sistema Kiosk Completo

Sistema de exibição automatizada em modo kiosk para TV, com interface administrativa remota e armazenamento local sem banco de dados.

---

## 🎯 Visão Geral

O CrediVision é um sistema completo para exibição de conteúdo em TVs e monitores, ideal para:
- 🏢 **Lobbies de empresas** - Informações corporativas
- 🏪 **Vitrines de lojas** - Promoções e produtos
- 🏥 **Salas de espera** - Informações de saúde
- 🎓 **Recepções** - Comunicados e avisos
- 🏭 **Indústrias** - Painéis de produção

---

## ✅ Funcionalidades Principais

### 📺 **Exibição Kiosk**
- 🌐 **Sites e URLs** - Iframes responsivos
- 🖼️ **Imagens** - PNG, JPG, JPEG, GIF (até 100MB)
- 🎥 **Vídeos** - MP4, AVI, MOV, WEBM (até 100MB)
- 🔄 **Rotação Automática** - Por duração configurada
- 🦊 **Firefox Kiosk** - Tela cheia sem bordas
- ⏱️ **Controle de Tempo** - 10s a 1 hora por aba

### 👥 **Gestão Administrativa**
- 🔐 **Login Seguro** - Hash SHA-256 + sessões
- 👑 **Admin/Viewer** - Controle de acesso
- 📊 **Dashboard** - Estatísticas em tempo real
- 📋 **Logs Completos** - Auditoria de todas ações
- 📱 **Acesso Remoto** - De qualquer dispositivo

### 💾 **Armazenamento Local**
- 🚫 **Sem Banco de Dados** - Zero dependência SQL
- 📁 **Arquivos JSON** - Configurações em `~/Documents/`
- 🗑️ **Exclusão Segura** - Remove arquivos do disco
- 💾 **Backup Simples** - Copiar pasta Documents
- 🔄 **Persistência Total** - Nada perdido ao reiniciar

### 🚀 **Automação**
- ⚡ **Boot Automático** - 45s até exibição
- ⏰ **Delay 30s** - Tela informativa
- 🐳 **Docker Container** - Isolamento e portabilidade
- 🔧 **Systemd Services** - Start/stop automático
- 🛡️ **Recuperação** - Restart em falhas

---

## 🏗️ Estrutura do Projeto

```
credvision/
├── 📄 app_no_db.py              # Backend Flask (sem DB)
├── 📄 app.py                    # Backend Flask (com SQLite)
├── 📄 requirements.txt          # Dependências Python
├── 📁 templates/                # Templates HTML
│   ├── base.html               # Layout base
│   ├── login.html              # Tela de login
│   ├── dashboard.html          # Dashboard principal
│   ├── tabs.html               # Gerenciamento de abas
│   ├── tabs_files.html         # Com exclusão de arquivos
│   ├── users.html              # Gestão de usuários
│   ├── logs.html               # Logs de auditoria
│   └── display.html            # Tela kiosk
├── 📁 static/                   # Arquivos estáticos
├── 📄 docker-compose.yml        # Configuração Docker
├── 📄 Dockerfile               # Imagem Docker
└── 📁 scripts/                  # Scripts de instalação
    ├── setup_ubuntu_kiosk.sh   # Instalação Ubuntu completa
    ├── create_admin.sh         # Gestão de usuários
    ├── backup_kiosk.sh         # Backup automático
    └── diagnose_kiosk.sh       # Diagnóstico
```

---

## 🚀 Instalação Rápida

### **Ubuntu (Recomendado)**
```bash
# Instalação completa automatizada
wget https://seu-repo.github.io/setup_ubuntu_kiosk.sh
sudo bash setup_ubuntu_kiosk.sh

# Configurar admin após instalação
sudo bash setup_admin_after_install.sh
```

### **Windows**
```bash
# Iniciar sistema
start_no_db.bat

# Configurar admin
create_admin.bat
```

### **Linux/Mac**
```bash
# Iniciar sistema
bash start_no_db.sh

# Configurar admin
sudo bash create_admin.sh
```

---

## 🌐 Acesso ao Sistema

### **Interface Administrativa**
```
URL: http://IP-DO-SERVIDOR:5000
Login: admin
Senha: admin123
```

### **Display Kiosk**
```
URL: http://IP-DO-SERVIDOR:5000/display
Modo: Firefox tela cheia (automático)
```

---

## 📋 Formatos Suportados

### 🖼️ **Imagens**
- **Formatos**: PNG, JPG, JPEG, GIF
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documents/kiosk-media/imagens/`

### 🎥 **Vídeos**
- **Formatos**: MP4, AVI, MOV, WEBM
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documents/kiosk-media/videos/`

### 🌐 **Sites**
- **Qualquer URL** acessível via iframe
- **Dashboards** e sistemas web
- **Páginas HTML** estáticas

---

## 🔧 Configuração

### **Arquivos de Configuração**
```bash
# Ubuntu
/opt/credvision/.env                    # Variáveis de ambiente
/home/user/Documents/kiosk-data/         # Dados JSON
/home/user/Documents/kiosk-media/        # Arquivos de mídia

# Windows
%USERPROFILE%\Documents\kiosk-data\     # Dados JSON
%USERPROFILE%\Documents\kiosk-media\    # Arquivos de mídia
```

### **Variáveis de Ambiente (.env)**
```bash
SECRET_KEY=sua_chave_secreta
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data                       # Docker
MEDIA_FOLDER=/media                      # Docker
ADMIN_URL=http://localhost:5000
KIOSK_MODE=full
CONFIG_REFRESH=300
MAX_FILE_SIZE=104857600                 # 100MB
```

---

## 🎮 Uso do Sistema

### **1. Configurar Conteúdo**
1. Acessar: `http://IP:5000`
2. Login: `admin` / `admin123`
3. Menu: "Abas / Conteúdo"
4. Clicar: "Nova Aba"
5. Escolher: URL ou Upload de arquivo
6. Configurar: Duração e nome
7. Salvar: Confirmar criação

### **2. Gerenciar Arquivos**
- **📤 Upload**: Arrastar e soltar arquivos
- **🗑️ Excluir Arquivo**: Botão específico (mantém aba)
- **🗑️ Excluir Aba**: Remove tudo (aba + arquivo)
- **📊 Visualizar**: Nome e tipo na tabela

### **3. Monitorar Sistema**
- **📊 Dashboard**: Estatísticas em tempo real
- **📋 Logs**: Histórico completo de ações
- **👥 Usuários**: Gerenciar acessos
- **🔄 Status**: Serviços e sistema

---

## 🔄 Fluxo de Boot

```
🔌 Ligar PC → 🚀 Ubuntu (15s) → ⏰ Tela 30s → 🐳 Docker → 🌐 Flask → 🦊 Firefox → 📺 Conteúdo
```

### **Timeline Detalhada:**
- **0-15s**: Ubuntu boot e systemd
- **15-45s**: Tela "Aguarde 30 segundos..." (Zenity)
- **20-40s**: Docker inicia container
- **30-50s**: Flask app ready
- **45s**: Firefox abre em modo kiosk
- **46s+**: Exibição contínua do conteúdo

---

## 💾 Armazenamento e Persistência

### **📁 Estrutura de Arquivos**
```
~/Documents/
├── 📁 kiosk-data/          ← DADOS DO SISTEMA (PERSISTENTE)
│   ├── 📄 tabs.json       ← Configurações das abas
│   ├── 👥 users.json      ← Usuários do sistema
│   └── 📋 logs.json       ← Logs de auditoria
├── 📁 kiosk-media/         ← ARQUIVOS DE MÍDIA (PERSISTENTE)
│   ├── 🖼️ imagens/        ← Imagens exibidas
│   ├── 🎥 videos/         ← Vídeos exibidos
│   └── 📄 outros/         ← Outros arquivos
└── 📁 kiosk-backups/       ← BACKUPS AUTOMÁTICOS
```

### **✅ O que PERSISTE:**
- 📄 **tabs.json** - Todas as configurações
- 📁 **kiosk-media/** - Todas as imagens/vídeos
- 👥 **users.json** - Usuários e permissões
- 📋 **logs.json** - Histórico completo

### **🔄 O que é Recriado:**
- 🐳 **Container Docker** - A cada boot
- 🦊 **Firefox** - Processo do kiosk
- 📊 **Sessões** - Login do admin

---

## 🛠️ Manutenção

### **Scripts Automáticos**
```bash
# Backup completo
sudo /opt/credvision/backup_kiosk.sh

# Diagnóstico do sistema
sudo /opt/credvision/diagnose_kiosk.sh

# Gerenciar usuários
sudo /opt/credvision/create_admin.sh

# Configurar admin (pós-instalação)
sudo /opt/credvision/setup_admin_after_install.sh
```

### **Comandos Úteis**
```bash
# Status dos serviços
sudo systemctl status credvision-app
sudo systemctl status credvision-kiosk

# Logs em tempo real
sudo journalctl -u credvision-app -f

# Reiniciar serviços
sudo systemctl restart credvision-app
sudo systemctl restart credvision-kiosk

# Backup manual
tar -czf backup-$(date +%Y%m%d).tar.gz \
  ~/Documents/kiosk-data \
  ~/Documents/kiosk-media
```

---

## 🚨 Troubleshooting

### **Problemas Comuns**

#### **Sistema não inicia**
```bash
# Verificar serviços
sudo systemctl status credvision-app credvision-kiosk

# Verificar Docker
docker ps
docker logs credvision-app

# Verificar arquivos
ls -la ~/Documents/kiosk-data/
ls -la ~/Documents/kiosk-media/
```

#### **Firefox não abre**
```bash
# Verificar display
echo $DISPLAY

# Iniciar manualmente
DISPLAY=:0 firefox --kiosk http://localhost:5000/display

# Verificar Xorg
ps aux | grep Xorg
```

#### **Upload falha**
```bash
# Verificar espaço
df -h ~/Documents/

# Verificar permissões
ls -la ~/Documents/kiosk-media/

# Limpar arquivos antigos
find ~/Documents/kiosk-media/ -mtime +30 -delete
```

---

## 📊 API Endpoints

### **Configuração**
```bash
GET /api/config
# Retorna: { "tabs": [...], "updated_at": "..." }
```

### **Status**
```bash
POST /api/status
# Envia: { "current_tab": "nome", "index": 0, "total": 3 }
# Retorna: { "status": "ok", "timestamp": "..." }
```

### **Mídia**
```bash
GET /media/<filename>
# Serve: Arquivos de imagem/vídeo
```

---

## 🔐 Segurança

### **Configurações Padrão**
- 🔐 **Hash SHA-256** para senhas
- 🕐 **Sessões expiram** em 1 hora
- 🚫 **Upload validado** - tipos e tamanho
- 🛡️ **Firewall UFW** - porta 5000 apenas
- 📋 **Logs completos** - auditoria total

### **Recomendações**
- 🔑 **Trocar senha** admin padrão
- 🌐 **HTTPS** em produção
- 📱 **Acesso restrito** à rede local
- 💾 **Backups regulares**
- 🔄 **Atualizações** de segurança

---

## 🎯 Versões Disponíveis

### **🚀 Versão Principal (Recomendada)**
- **Arquivo**: `app_no_db.py`
- **Armazenamento**: Arquivos JSON
- **Vantagens**: Setup rápido, backup simples, portabilidade
- **Uso**: Pequenas/médias instalações

### **🗄️ Versão com SQLite**
- **Arquivo**: `app.py`
- **Armazenamento**: Banco SQLite
- **Vantagens**: Consultas complexas, escalabilidade
- **Uso**: Grandes instalações, relatórios

---

## 📞 Suporte

### **Documentação**
- 📖 **README.md** - Este guia
- 🎨 **DIAGRAMA_FLUXO.md** - Fluxo visual
- 📋 **FLUXO_SISTEMA.md** - Explicação detalhada

### **Scripts**
- 🚀 **setup_ubuntu_kiosk.sh** - Instalação completa
- 👥 **create_admin.sh** - Gestão de usuários
- 🔍 **diagnose_kiosk.sh** - Diagnóstico
- 💾 **backup_kiosk.sh** - Backup

### **Comunidade**
- 📧 **Email**: suporte@credvision.com
- 💬 **Telegram**: @credvision-support
- 🌐 **Web**: https://credvision.com/support

---

## 🎊 Benefícios

### **Para o Negócio**
- 📈 **Profissionalismo** - Exibição automatizada
- 💰 **Economia** - Sem papel nem impressão
- 🔄 **Atualização** - Conteúdo em tempo real
- 📊 **Controle** - Gestão centralizada

### **Para o TI**
- ⚡ **Setup rápido** - Instalação automatizada
- 🛡️ **Segurança** - Controle de acesso
- 💾 **Backup simples** - Copiar pasta
- 🔧 **Manutenção** - Scripts automatizados

### **Para o Usuário**
- 📱 **Acesso remoto** - Gerenciar de qualquer lugar
- 🎨 **Interface intuitiva** - Fácil uso
- 📺 **Exibição profissional** - Sem intervenção manual
- 🔄 **Conteúdo dinâmico** - Vários formatos

---

**🎉 CrediVision - Sistema Kiosk Completo e Profissional!**

*Transforme qualquer TV em um painel informativo automatizado.*
