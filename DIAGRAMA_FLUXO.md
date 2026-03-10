# 🎯 Diagrama Visual do Fluxo CrediVision Kiosk

## 📺 Fluxo Completo: Boot → Exibição

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🔌 LIGAR     │    │   🚀 Ubuntu     │    │   ⏰ 30s        │
│   Computador    │───▶│   Boot (15s)    │───▶│   Contador      │
│                 │    │                 │    │                 │
│ • Power On      │    │ • Systemd start │    │ • Zenity screen │
│ • BIOS/UEFI     │    │ • Services load │    │ • "Aguarde 30s" │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🐳 Docker     │    │   🌐 Flask      │    │   🦊 Firefox    │
│   Start         │    │   App Start     │    │   Kiosk         │
│                 │    │                 │    │                 │
│ • docker compose│───▶│ • app_no_db.py  │───▶│ • --kiosk mode  │
│ • build image   │    │ • load JSONs    │    │ • fullscreen    │
│ • run container │    │ • :5000 ready   │    │ • localhost:5000│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        📺 EXIBIÇÃO CONTÍNUA                     │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   🖼️ Img 1   │    │   🌐 Site    │    │   🎥 Vid 3   │         │
│  │   (15s)     │───▶│   (30s)     │───▶│   (45s)     │───▶   │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
│  📋 Lê tabs.json → 🔄 Rotaciona → 📺 Exibe → 🔁 Repete        │
└─────────────────────────────────────────────────────────────────┘
```

## 📱 Fluxo de Administração

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   📱 Admin      │    │   🌐 Flask      │    │   💾 Arquivos   │
│   Acessa        │    │   Processa      │    │   Salvos        │
│                 │    │                 │    │                 │
│ • Celular/PC    │───▶│ • HTTP Request  │───▶│ • ~/Documents/ │
│ • http://IP     │    │ • Autenticação  │    │ • tabs.json     │
│ • Login admin   │    │ • CRUD JSON     │    │ • users.json    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   📊 Dashboard   │    │   📁 Upload     │    │   🔄 Kiosk     │
│   Interface     │    │   Arquivos      │    │   Atualizado    │
│                 │    │                 │    │                 │
│ • Ver abas      │───▶│ • Salva em      │───▶│ • Lê JSONs      │
│ • Add/Edit      │    │   kiosk-media/  │    │ • Atualiza     │
│ • Delete files  │    │ • Valida        │    │ • Exibe novo   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 Ciclo de Persistência

```
┌─────────────────────────────────────────────────────────────────┐
│                    💾 PERSISTÊNCIA TOTAL                        │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐  │
│  │   🔌 Ligar      │    │   ⚙️ Usar       │    │   🔌 Desligar│  │
│  │   Computador    │───▶│   Sistema       │───▶│   Computador │  │
│  └─────────────────┘    └─────────────────┘    └─────────────┘  │
│           │                       │                       │      │
│           ▼                       ▼                       ▼      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐  │
│  │   📂 Carregar    │    │   💾 Salvar      │    │   💾 Dados   │  │
│  │   JSONs         │───▶│   Alterações    │───▶│   Mantidos   │  │
│  │   ~/Documents/  │    │   ~/Documents/  │    │   ~/Documents/│  │
│  └─────────────────┘    └─────────────────┘    └─────────────┘  │
│                                                                 │
│  ✅ NADA É PERDIDO AO REINICIAR!                                │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    🖥️ COMPUTADOR UBUNTU                        │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   👤 USUÁRIO     │    │   🔧 ROOT       │                    │
│  │   Ubuntu        │    │   System Admin  │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                              │
│           ▼                       ▼                              │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   🏠 /home/ubuntu/                        │  │
│  │                                                           │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │ Documents/  │  │ Downloads/  │  │ Pictures/   │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  │         │               │               │                │  │
│  │         ▼               ▼               ▼                │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │kiosk-data/  │  │kiosk-media/ │  │kiosk-back/  │        │  │
│  │  │ tabs.json   │  │ imagens/    │  │ backup*.tgz │        │  │
│  │  │ users.json  │  │ videos/     │  │             │        │  │
│  │  │ logs.json   │  │ outros/     │  │             │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  └─────────────────────────────────────────────────────────────┘  │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   🐳 DOCKER CONTAINER                      │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │            Python Flask App                          │   │  │
│  │  │                                                     │   │  │
│  │  │  🌐 Port 5000                                       │   │  │
│  │  │  📁 /data (bind) → ~/Documents/kiosk-data          │   │  │
│  │  │  📁 /media (bind) → ~/Documents/kiosk-media        │   │  │
│  │  │  📋 app_no_db.py                                   │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────────┘  │
│           │                                                   │
│           ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                   🦊 FIREFOX KIOSK                        │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │            http://localhost:5000/display           │   │  │
│  │  │                                                     │   │  │
│  │  │  🖥️ Fullscreen Mode                                  │   │  │
│  │  │  🔄 Auto-rotate tabs                                │   │  │
│  │  │  📺 Display on TV                                   │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                 │
│  🌐 Acesso Admin: http://IP-DO-PC:5000 (de qualquer device)   │
└─────────────────────────────────────────────────────────────────┘
```

## ⚡ Timeline de Boot (Segundos)

```
0s     5s     10s     15s     20s     25s     30s     35s     40s
│      │      │      │      │      │      │      │      │
├──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │      │      │      │      │
🔌     🚀     ⏰     🐳     🌐     🦊     📺     🔄
Power  Ubuntu 30s    Docker Flask Firefox Kiosk  Rotation
On     Boot   Zenity Start Ready Open  Display
```

## 📋 Services Systemd

```
┌─────────────────────────────────────────────────────────────────┐
│                    📋 SYSTEMD SERVICES                         │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │ credvision-app  │    │ credvision-boot │                    │
│  │                 │    │                 │                    │
│  │ • Docker Compose│───▶│ • Zenity Screen │                    │
│  │ • Start Container│   │ • 30s countdown │                    │
│  │ • Port 5000     │   │ • Info message  │                    │
│  │ • Restart always│   │ • No restart    │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                              │
│           ▼                       ▼                              │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │ credvision-kiosk│    │ credvision-back │                    │
│  │                 │    │                 │                    │
│  │ • Firefox Kiosk │    │ • Daily backup  │                    │
│  │ • 30s delay     │    │ • Tar.gz files  │                    │
│  │ • Restart always│   │ • Timer trigger  │                    │
│  │ • :0 display    │   │ • Auto cleanup  │                    │
│  └─────────────────┘    └─────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Casos de Uso

### **🏢 Empresa - Lobby**
```
TV Lobby ←→ WiFi ←→ Celular Gerente
    ↓           ↓           ↓
  Kiosk      Ubuntu      Browser
  Display    Server      Admin
```

### **🏪 Loja - Promocional**
```
TV Vitrine ←→ Rede Local ←→ Tablet Vendedor
    ↓              ↓              ↓
  Promos       Ubuntu        Admin
  Fotos        Kiosk          Upload
```

### **🏥 Hospital - Espera**
```
TV Sala ←→ Intranet ←→ Secretaria
    ↓         ↓           ↓
  Infos    Ubuntu      Admin
  Saúde    Kiosk        Update
```

---

## 🎊 Resumo do Fluxo Perfeito

### **✅ O que ACONTECE:**
1. **Ligar PC** → Ubuntu boot automaticamente
2. **30s** → Tela informativa "Aguarde..."
3. **Docker** → Sobe container Flask
4. **Firefox** → Abre em modo kiosk
5. **Exibição** → Rotaciona conteúdo automaticamente
6. **Admin** → Gerencia remotamente via web

### **✅ O que PERSISTE:**
- **Configurações** em `~/Documents/kiosk-data/`
- **Arquivos** em `~/Documents/kiosk-media/`
- **Logs** em `~/Documents/kiosk-data/logs.json`
- **TUDO** mantido ao reiniciar/desligar

### **✅ O que é AUTOMÁTICO:**
- **Boot** do sistema
- **Início** do kiosk
- **Rotação** do conteúdo
- **Backup** diário
- **Recuperação** de falhas

**🎯 Sistema 100% Plug-and-Play para TV!**
