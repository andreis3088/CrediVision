# 📋 Configuração do Repositório Git

## 🎯 O que você precisa fazer:

### 1. **Criar o Repositório Git**

Crie um repositório no GitHub/GitLab/Bitbucket com o nome `credvision`.

### 2. **Atualizar o Script de Instalação**

No arquivo `setup_ubuntu_complete.sh`, linha 67, altere:

```bash
# DE:
GIT_REPO="https://github.com/SEU-USUARIO/credvision.git"

# PARA:
GIT_REPO="https://github.com/SEU-USUARIO-NOME/credvision.git"
```

### 3. **Fazer Upload dos Arquivos**

```bash
# Inicializar repositório local
git init
git add .
git commit -m "Initial commit - CrediVision v1.0"

# Adicionar remoto
git remote add origin https://github.com/SEU-USUARIO/credvision.git

# Enviar para o repositório
git push -u origin main
```

### 4. **Arquivos que serão Enviados**

- ✅ `app.py` - Backend Flask
- ✅ `requirements.txt` - Dependências Python
- ✅ `Dockerfile.ubuntu` - Docker para Ubuntu
- ✅ `docker-compose.ubuntu.yml` - Orquestração
- ✅ `templates/` - Todos os templates HTML
- ✅ `setup_ubuntu_complete.sh` - Script instalação
- ✅ `README_UBUNTU.md` - Documentação
- ✅ `RESUMO_SISTEMA.md` - Resumo completo

### 5. **Estrutura no GitHub**

```
credvision/
├── 📁 templates/
│   ├── base.html
│   ├── login.html
│   ├── dashboard.html
│   ├── tabs.html
│   ├── users.html
│   ├── logs.html
│   └── display.html
├── 🐍 app.py
├── 📋 requirements.txt
├── 🐳 Dockerfile.ubuntu
├── 🐳 docker-compose.ubuntu.yml
├── 🚀 setup_ubuntu_complete.sh
├── 📖 README_UBUNTU.md
├── 📊 RESUMO_SISTEMA.md
└── 📝 GIT_CONFIG.md
```

### 6. **Após Configurar**

1. **Teste localmente**: `python app.py`
2. **Crie o repositório GitHub**
3. **Atualize o script com sua URL**
4. **Faça upload dos arquivos**
5. **Teste instalação em VM Ubuntu**

---

## 🔧 Comandos Git Essenciais

```bash
# Configurar usuário
git config --global user.name "Seu Nome"
git config --global user.email "seu.email@exemplo.com"

# Inicializar repositório
git init
git add .
git commit -m "CrediVision v1.0 - Sistema completo"

# Conectar ao GitHub
git remote add origin https://github.com/SEU-USUARIO/credvision.git
git branch -M main
git push -u origin main

# Atualizar repositório
git add .
git commit -m "Atualização"
git push origin main
```

---

## 📝 Exemplo Completo

```bash
# 1. Clonar seu repositório
git clone https://github.com/SEU-USUARIO/credvision.git
cd credvision

# 2. Copiar arquivos do projeto
cp -r /caminho/do/projeto/* .

# 3. Adicionar e commitar
git add .
git commit -m "CrediVision v1.0 - Sistema kiosk completo"

# 4. Enviar para GitHub
git push origin main

# 5. Testar instalação
# Em máquina Ubuntu:
wget https://raw.githubusercontent.com/SEU-USUARIO/credvision/main/setup_ubuntu_complete.sh
sudo bash setup_ubuntu_complete.sh
```

---

**⚠️ IMPORTANTE**: Não se esqueça de atualizar a variável `GIT_REPO` no script de instalação com a URL correta do seu repositório!
