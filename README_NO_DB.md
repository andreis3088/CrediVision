# 🖥️ CrediVision - Versão SEM BANCO DE DADOS

Sistema completo de exibição automatizada em modo kiosk para TV, com armazenamento local em arquivos JSON.

---

## 🎯 Diferenças da Versão SEM BANCO DE DADOS

### ✅ **Vantagens**
- 🚫 **Sem Banco de Dados** - Zero dependência de SQLite/MySQL
- 📁 **Armazenamento Local** - Arquivos JSON em `~/Documentos/`
- 💾 **Backup Simples** - Apenas copiar pasta
- 🔄 **Portabilidade Total** - Funciona em qualquer sistema
- 🗑️ **Exclusão Segura** - Remove arquivos do disco
- ⚡ **Performance** - Leitura/escrita rápida de JSON

### 📁 **Estrutura de Arquivos**
```
~/Documents/kiosk-data/
├── 📄 tabs.json      - Abas configuradas
├── 👥 users.json     - Usuários do sistema
└── 📋 logs.json      - Logs de auditoria

~/Documents/kiosk-media/
├── 🖼️ imagens/       - Arquivos de imagem
├── 🎥 videos/        - Arquivos de vídeo
└── 📄 outros/        - Outros arquivos
```

---

## 🚀 Instalação Rápida

### **Windows**
```bash
# Executar script
start_no_db.bat
```

### **Linux/Mac**
```bash
# Executar script
bash start_no_db.sh
```

### **Ubuntu (Instalação Completa)**
```bash
# Download e execução automática
wget https://seu-repo.github.io/setup_ubuntu_no_db.sh
sudo bash setup_ubuntu_no_db.sh
```

---

## 🎮 Funcionalidades Principais

### 📺 **Gestão de Conteúdo**
- 🌐 **Sites e URLs** - Iframes responsivos
- 🖼️ **Imagens** - PNG, JPG, JPEG, GIF
- 🎥 **Vídeos** - MP4, AVI, MOV, WEBM
- 📁 **Upload Local** - Arrastar e soltar
- 🗑️ **Exclusão de Arquivos** - Remove do disco

### 👥 **Gestão de Usuários**
- 🔐 **Autenticação Segura** - Hash SHA-256
- 👑 **Admin/Viewer** - Controle de acesso
- 📝 **Logs Completos** - Auditoria total

### 🔄 **Automação**
- ⏱️ **Rotação Automática** - Por duração configurada
- 🎯 **Modo Kiosk** - Firefox em tela cheia
- 📊 **API REST** - Integração fácil

---

## 📋 Formatos Suportados

### 🖼️ **Imagens**
- **Formatos**: PNG, JPG, JPEG, GIF
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documents/kiosk-media/`

### 🎥 **Vídeos**
- **Formatos**: MP4, AVI, MOV, WEBM
- **Tamanho**: Máximo 100MB
- **Local**: `~/Documents/kiosk-media/`

### 🌐 **Sites**
- **Qualquer URL** acessível via iframe
- **Dashboards** e sistemas web
- **Páginas HTML** estáticas

---

## 🔧 Configuração

### **Arquivos JSON**

#### **tabs.json**
```json
[
  {
    "id": 1,
    "name": "Dashboard Vendas",
    "url": "https://dashboard.com",
    "content_type": "url",
    "file_path": null,
    "duration": 300,
    "active": true,
    "order_index": 0,
    "created_at": "2024-01-15T14:30:00",
    "updated_at": "2024-01-15T14:30:00"
  },
  {
    "id": 2,
    "name": "Promoção Banner",
    "url": "/media/promocao.jpg",
    "content_type": "image",
    "file_path": "/home/user/Documents/kiosk-media/promocao.jpg",
    "duration": 60,
    "active": true,
    "order_index": 1,
    "created_at": "2024-01-15T14:35:00",
    "updated_at": "2024-01-15T14:35:00"
  }
]
```

#### **users.json**
```json
[
  {
    "id": 1,
    "username": "admin",
    "password_hash": "ee505b91afeebf166090...",
    "role": "admin",
    "created_at": "2024-01-15T14:30:00"
  }
]
```

#### **logs.json**
```json
[
  {
    "id": 1,
    "user": "admin",
    "action": "tab_add",
    "details": "Aba adicionada: Dashboard Vendas",
    "ip": "192.168.1.100",
    "created_at": "2024-01-15T14:30:00"
  }
]
```

---

## 🎮 Uso do Sistema

### **1. Acesso Administrativo**
```bash
# Abrir navegador
http://localhost:5000

# Login padrão
Usuário: admin
Senha: admin123
```

### **2. Adicionar Conteúdo**
1. **Acessar**: "Abas / Conteúdo"
2. **Clicar**: "Nova Aba"
3. **Escolher tipo**:
   - **URL**: Digitar endereço
   - **Arquivo**: Upload de imagem/vídeo
4. **Configurar**: Duração e nome
5. **Salvar**: Confirmar criação

### **3. Excluir Arquivos**
- **🗑️ Excluir Apenas Arquivo**: Mantém aba, remove arquivo
- **🗑️ Excluir Aba Completa**: Remove aba e arquivo
- **⚠️ Confirmação**: Alerta sobre exclusão permanente

### **4. Display Kiosk**
```bash
# Abrir modo kiosk
http://localhost:5000/display

# Ou Firefox automático
firefox --kiosk http://localhost:5000/display
```

---

## 🛠️ Manutenção

### **Backup Completo**
```bash
# Parar serviços
sudo systemctl stop credvision-no-db

# Copiar pasta
cp -r ~/Documents/kiosk-data ~/backup/kiosk-data-$(date +%Y%m%d)
cp -r ~/Documents/kiosk-media ~/backup/kiosk-media-$(date +%Y%m%d)

# Reiniciar serviços
sudo systemctl start credvision-no-db
```

### **Restauração**
```bash
# Parar serviços
sudo systemctl stop credvision-no-db

# Restaurar backup
cp -r ~/backup/kiosk-data-20240115/* ~/Documents/kiosk-data/
cp -r ~/backup/kiosk-media-20240115/* ~/Documents/kiosk-media/

# Reiniciar serviços
sudo systemctl start credvision-no-db
```

### **Scripts Automáticos**
```bash
# Backup automático
sudo /opt/credvision/backup_no_db.sh

# Diagnóstico completo
sudo /opt/credvision/diagnose_no_db.sh

# Status dos serviços
sudo systemctl status credvision-no-db
```

---

## 🔧 Comandos Úteis

### **Gerenciamento**
```bash
# Iniciar sistema
sudo systemctl start credvision-no-db

# Parar sistema
sudo systemctl stop credvision-no-db

# Reiniciar
sudo systemctl restart credvision-no-db

# Ver status
sudo systemctl status credvision-no-db

# Ver logs
sudo journalctl -u credvision-no-db -f
```

### **Arquivos**
```bash
# Ver abas
cat ~/Documents/kiosk-data/tabs.json

# Ver usuários
cat ~/Documents/kiosk-data/users.json

# Ver logs
cat ~/Documents/kiosk-data/logs.json | tail -20

# Contar abas
cat ~/Documents/kiosk-data/tabs.json | jq '. | length'

# Backup rápido
tar -czf kiosk-backup-$(date +%Y%m%d).tar.gz \
  ~/Documents/kiosk-data \
  ~/Documents/kiosk-media
```

---

## 🚨 Troubleshooting

### **Problemas Comuns**

#### **1. Sistema não inicia**
```bash
# Verificar permissões
ls -la ~/Documents/kiosk-data/
ls -la ~/Documents/kiosk-media/

# Corrigir permissões
chmod 755 ~/Documents/kiosk-data/
chmod 755 ~/Documents/kiosk-media/
chown -R $USER:$USER ~/Documents/kiosk-data/
chown -R $USER:$USER ~/Documents/kiosk-media/

# Verificar logs
sudo journalctl -u credvision-no-db -n 50
```

#### **2. Arquivos não aparecem**
```bash
# Verificar estrutura
find ~/Documents/kiosk-media/ -type f

# Verificar JSON
cat ~/Documents/kiosk-data/tabs.json | jq

# Reconstruir arquivos
sudo /opt/credvision/diagnose_no_db.sh
```

#### **3. Upload falha**
```bash
# Verificar espaço em disco
df -h ~/Documents/

# Verificar permissões
ls -la ~/Documents/kiosk-media/

# Limpar arquivos antigos
find ~/Documents/kiosk-media/ -mtime +30 -delete
```

#### **4. Firefox não abre**
```bash
# Verificar display
echo $DISPLAY

# Instalar Firefox
sudo apt install firefox

# Iniciar manualmente
DISPLAY=:0 firefox --kiosk http://localhost:5000/display
```

---

## 📊 Monitoramento

### **API Endpoints**
```bash
# Configuração atual
curl http://localhost:5000/api/config

# Status do kiosk
curl -X POST http://localhost:5000/api/status \
  -H "Content-Type: application/json" \
  -d '{"current_tab":"test","index":0,"total":1}'
```

### **Logs em Tempo Real**
```bash
# Logs do sistema
sudo journalctl -u credvision-no-db -f

# Logs de auditoria
tail -f ~/Documents/kiosk-data/logs.json

# Logs do Firefox
tail -f ~/.xsession-errors
```

---

## 🎯 Migração (Com DB → Sem DB)

### **Exportar do SQLite**
```bash
# Converte SQLite para JSON
python3 migrate_to_json.py
```

### **Importar para JSON**
```bash
# Copiar arquivos convertidos
cp converted_tabs.json ~/Documents/kiosk-data/tabs.json
cp converted_users.json ~/Documents/kiosk-data/users.json
cp converted_logs.json ~/Documents/kiosk-data/logs.json
```

---

## 🎊 Benefícios da Versão SEM DB

### **Para Desenvolvimento**
- ⚡ **Setup Rápido** - Zero configuração de DB
- 🔄 **Debug Fácil** - Arquivos legíveis
- 🧪 **Testes Simples** - Mock com JSON

### **Para Produção**
- 💾 **Backup Simples** - Copiar e colar
- 🚀 **Deploy Rápido** - Apenas copiar arquivos
- 🛡️ **Recuperação** - Restaurar em minutos

### **Para Manutenção**
- 📊 **Visualização** - Ler JSON diretamente
- ✏️ **Edição Manual** - Editar arquivos
- 🔍 **Debug** - Arquivos transparentes

---

## 📞 Suporte

### **Documentação**
- 📖 **README_NO_DB.md** - Este guia
- 🚀 **setup_ubuntu_no_db.sh** - Instalação completa
- 🧪 **app_no_db.py** - Código fonte comentado

### **Comunidade**
- 📧 **Email**: suporte@credvision.com
- 💬 **Telegram**: @credvision-support
- 🌐 **Web**: https://credvision.com/support

---

**🎉 Versão SEM BANCO DE DADOS - Simples, Rápida e Portátil!**

*Perfeita para pequenas instalações, desenvolvimento e sistemas que precisam de portabilidade total.*
