# 🚀 Guia de Instalação - CrediVision Ubuntu

## 📋 Visão Geral

Este guia explica como instalar e configurar o CrediVision no Ubuntu com início automático, Docker e modo kiosk.

---

## 🎯 Pré-requisitos

### **Hardware Mínimo**
- **CPU**: 2 cores (recomendado 4+)
- **RAM**: 4GB (recomendado 8GB+)
- **Armazenamento**: 20GB livre
- **Rede**: Conexão internet para instalação

### **Software**
- **Ubuntu 20.04+** (Desktop preferencial)
- **Acesso root/sudo**
- **Repositório já clonado**

---

## 🚀 Instalação Automática

### **1. Baixar e Clonar (se ainda não tiver)**
```bash
# Clonar repositório
git clone https://github.com/SEU-USUARIO/credvision.git
cd credvision

# Ou se já tiver clonado
cd /caminho/para/credvision
```

### **2. Executar Script de Instalação**
```bash
# Tornar executável
chmod +x setup_ubuntu_local.sh

# Executar instalação
sudo bash setup_ubuntu_local.sh
```

### **3. Aguardar Instalação**
O script realizará automaticamente:
- ✅ Atualização do sistema
- ✅ Instalação do Docker
- ✅ Configuração de ambiente Python
- ✅ Criação de diretórios
- ✅ Configuração de serviços systemd
- ✅ Criação de usuário admin
- ✅ Teste de funcionamento

---

## 🔧 Configurações Após Instalação

### **🌐 Porta do Serviço**

**Porta Padrão**: `5000`

**Para alterar a porta:**
```bash
# Editar docker-compose.yml
nano docker-compose.yml

# Alterar a linha:
ports:
  - "5000:5000"  # Para "NOVA_PORTA:5000"

# Reiniciar serviços
sudo systemctl restart credvision-app
```

**Acessar o sistema:**
- **Admin**: `http://IP_DO_SERVIDOR:5000`
- **Display**: `http://IP_DO_SERVIDOR:5000/display`

---

### **🐳 Docker Início Automático**

O Docker é configurado automaticamente para iniciar com o sistema:

```bash
# Verificar status do Docker
sudo systemctl status docker

# Habilitar Docker (já feito pelo script)
sudo systemctl enable docker

# Iniciar Docker manualmente
sudo systemctl start docker
```

**Verificar container do CrediVision:**
```bash
# Verificar containers rodando
docker ps

# Verificar logs do container
docker logs credvision-app

# Verificar status do serviço
sudo systemctl status credvision-app
```

---

### **🦊 Firefox Kiosk Configuração**

O modo kiosk já é configurado automaticamente pelo script:

**Configurações aplicadas:**
- **URL**: `http://localhost:5000/display`
- **Delay**: 30 segundos após início do app
- **Modo**: Tela cheia sem bordas
- **Restart**: Automático em caso de falha

**Serviço do Kiosk:**
```bash
# Verificar status
sudo systemctl status credvision-kiosk

# Iniciar manualmente
sudo systemctl start credvision-kiosk

# Parar
sudo systemctl stop credvision-kiosk

# Reiniciar
sudo systemctl restart credvision-kiosk
```

**Configuração manual (se necessário):**
```bash
# Editar serviço
sudo nano /etc/systemd/system/credvision-kiosk.service

# Linha importante:
ExecStart=/bin/bash -c 'sleep 30 && /usr/bin/firefox --kiosk http://localhost:5000/display --no-first-run --disable-pinch --disable-infobars'
```

---

## 🔄 Serviços Systemd (Início Automático)

### **Serviços Configurados**

| Serviço | Função | Status |
|---------|--------|--------|
| `credvision-app.service` | Docker + Flask App | ✅ Habilitado |
| `credvision-kiosk.service` | Firefox Kiosk | ✅ Habilitado |
| `credvision-boot.service` | Tela inicial | ✅ Habilitado |
| `credvision-backup.timer` | Backup diário | ✅ Habilitado |

### **Gerenciamento dos Serviços**

```bash
# Verificar todos os serviços
sudo systemctl status credvision-*

# Habilitar todos (já feito)
sudo systemctl enable credvision-app credvision-kiosk credvision-boot

# Iniciar todos
sudo systemctl start credvision-app credvision-kiosk

# Parar todos
sudo systemctl stop credvision-app credvision-kiosk

# Reiniciar todos
sudo systemctl restart credvision-app credvision-kiosk
```

---

## 📁 Estrutura de Arquivos

### **Diretórios Criados**
```bash
/home/user/Documents/
├── 📁 kiosk-data/          ← Dados JSON (persistente)
│   ├── 📄 tabs.json       ← Configurações das abas
│   ├── 👥 users.json      ← Usuários do sistema
│   └── 📋 logs.json       ← Logs de auditoria
├── 📁 kiosk-media/         ← Arquivos de mídia (persistente)
│   ├── 🖼️ imagens/        ← Imagens
│   ├── 🎥 videos/         ← Vídeos
│   └── 📄 outros/         ← Outros arquivos
└── 📁 kiosk-backups/       ← Backups automáticos

/opt/credvision/             ← Projeto (se movido)
├── 📄 app_no_db.py         ← Backend principal
├── 📄 docker-compose.yml   ← Configuração Docker
├── 📄 Dockerfile           ← Imagem Docker
├── 📄 .env                 ← Variáveis ambiente
└── 📁 scripts/             ← Scripts manutenção
```

---

## 🎮 Uso do Sistema

### **🔐 Primeiro Acesso**

1. **Acessar Interface Admin**:
   ```
   http://IP_DO_SERVIDOR:5000
   ```

2. **Login Padrão**:
   ```
   Usuário: admin
   Senha: admin123
   ```

3. **Trocar Senha**:
   - Menu "Usuários"
   - Editar usuário admin
   - Definir nova senha

### **📺 Configurar Conteúdo**

1. **Adicionar Abas**:
   - Menu "Abas / Conteúdo"
   - Clicar "Nova Aba"
   - Escolher tipo (URL ou Arquivo)
   - Upload de imagem/vídeo ou digitar URL
   - Definir duração
   - Salvar

2. **Gerenciar Arquivos**:
   - Upload via interface
   - Excluir arquivos individualmente
   - Arquivos salvos em `~/Documents/kiosk-media/`

### **🔄 Verificar Funcionamento**

```bash
# Diagnóstico completo
sudo /opt/credvision/diagnose_kiosk.sh

# Teste de API
curl http://localhost:5000/api/config

# Verificar logs
sudo journalctl -u credvision-app -f
```

---

## 🛠️ Manutenção

### **📊 Scripts Disponíveis**

```bash
# Diagnóstico completo
sudo /opt/credvision/diagnose_kiosk.sh

# Backup manual
sudo /opt/credvision/backup_kiosk.sh

# Gerenciar usuários
sudo /opt/credvision/create_admin.sh
```

### **🔄 Backup Automático**

- **Frequência**: Diário
- **Horário**: 00:00 (meia-noite)
- **Local**: `~/Documents/kiosk-backups/`
- **Retenção**: 7 dias

**Verificar timer de backup:**
```bash
sudo systemctl status credvision-backup.timer
sudo systemctl list-timers credvision-backup
```

### **📋 Logs do Sistema**

```bash
# Logs do serviço principal
sudo journalctl -u credvision-app -f

# Logs do kiosk
sudo journalctl -u credvision-kiosk -f

# Logs do Docker
docker logs credvision-app -f

# Logs de boot
sudo journalctl -u credvision-boot
```

---

## 🚨 Troubleshooting

### **🔥 Problemas Comuns**

#### **Sistema não inicia**
```bash
# Verificar serviços
sudo systemctl status credvision-app credvision-kiosk

# Verificar Docker
sudo systemctl status docker
docker ps

# Reiniciar tudo
sudo systemctl restart docker
sudo systemctl restart credvision-app
sudo systemctl restart credvision-kiosk
```

#### **Firefox não abre**
```bash
# Verificar display
echo $DISPLAY

# Verificar Xorg
ps aux | grep Xorg

# Iniciar manualmente
DISPLAY=:0 firefox --kiosk http://localhost:5000/display
```

#### **API não responde**
```bash
# Verificar porta
netstat -tlnp | grep :5000

# Verificar container
docker ps | grep credvision-app
docker logs credvision-app

# Testar localmente
curl http://localhost:5000/api/config
```

#### **Upload falha**
```bash
# Verificar espaço em disco
df -h ~/Documents/

# Verificar permissões
ls -la ~/Documents/kiosk-media/

# Corrigir permissões
sudo chown -R $USER:$USER ~/Documents/kiosk-media/
chmod 755 ~/Documents/kiosk-media/
```

### **🔄 Reset Completo**

```bash
# Parar tudo
sudo systemctl stop credvision-app credvision-kiosk

# Limpar containers
docker stop credvision-app
docker rm credvision-app

# Reiniciar sistema
sudo systemctl start credvision-app
sleep 30
sudo systemctl start credvision-kiosk
```

---

## 🎯 Configurações Avançadas

### **🌐 Alterar Porta do Serviço**

```bash
# 1. Editar docker-compose.yml
nano docker-compose.yml

# 2. Alterar linha ports:
ports:
  - "NOVA_PORTA:5000"

# 3. Editar serviço kiosk
sudo nano /etc/systemd/system/credvision-kiosk.service

# 4. Alterar URL:
ExecStart=/bin/bash -c 'sleep 30 && /usr/bin/firefox --kiosk http://localhost:NOVA_PORTA/display'

# 5. Recarregar e reiniciar
sudo systemctl daemon-reload
sudo systemctl restart credvision-app credvision-kiosk
```

### **🔧 Alterar Delay do Kiosk**

```bash
# Editar serviço
sudo nano /etc/systemd/system/credvision-kiosk.service

# Alterar sleep:
ExecStart=/bin/bash -c 'sleep NOVO_TEMPO && /usr/bin/firefox --kiosk ...'

# Recarregar e reiniciar
sudo systemctl daemon-reload
sudo systemctl restart credvision-kiosk
```

### **📁 Mover Diretório de Dados**

```bash
# 1. Parar serviços
sudo systemctl stop credvision-app credvision-kiosk

# 2. Mover dados
sudo mv ~/Documents/kiosk-data /novo/caminho/
sudo mv ~/Documents/kiosk-media /novo/caminho/

# 3. Editar docker-compose.yml
nano docker-compose.yml
# Alterar volumes:
volumes:
  - /novo/caminho/kiosk-data:/data:rw
  - /novo/caminho/kiosk-media:/media:rw

# 4. Reiniciar
sudo systemctl start credvision-app
```

---

## 📊 Monitoramento

### **🔍 Status em Tempo Real**

```bash
# Script de monitoramento
watch -n 5 'sudo systemctl status credvision-* | grep Active'

# Monitorar Docker
watch -n 5 'docker ps | grep credvision'

# Monitorar portas
watch -n 5 'netstat -tlnp | grep :5000'
```

### **📈 Performance**

```bash
# Uso de recursos
htop

# Uso de disco
df -h ~/Documents/

# Logs de erro
sudo journalctl -p err -f
```

---

## 🎊 Resumo Final

### **✅ O que foi Configurado**

1. **Docker** - Início automático com sistema
2. **CrediVision App** - Container Docker automático
3. **Firefox Kiosk** - Inicia 30s após app
4. **Backup Diário** - Automático e configurado
5. **Persistência** - Dados mantidos em ~/Documents/
6. **Logs** - Auditoria completa do sistema

### **🌐 Acessos**

- **Admin**: `http://IP:5000` (admin/admin123)
- **Display**: `http://IP:5000/display` (kiosk automático)
- **Porta**: 5000 (configurável)

### **🔄 Inicialização Automática**

Ao ligar o computador:
1. **Ubuntu boot** (15-20s)
2. **Docker inicia** (5-10s)
3. **CrediVision app** (10-15s)
4. **Firefox kiosk** (30s delay)
5. **Exibição conteúdo** (automática)

**🎉 Sistema pronto para uso 24/7!**
