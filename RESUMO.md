# 🎯 CrediVision - Resumo Rápido

## 🚀 O que é?
Sistema kiosk para TV com exibição automática de conteúdo (imagens, vídeos, sites).

## ⚡ Instalação Ubuntu
```bash
sudo bash setup_ubuntu_kiosk.sh
sudo bash setup_admin_after_install.sh
```

## 🌐 Acesso
- **Admin**: http://IP:5000 (admin/admin123)
- **Kiosk**: http://IP:5000/display

## 📁 Armazenamento
- **Dados**: `~/Documents/kiosk-data/` (JSON)
- **Mídia**: `~/Documents/kiosk-media/` (arquivos)

## 🔧 Comandos Úteis
```bash
# Status
sudo systemctl status credvision-app

# Diagnóstico
sudo /opt/credvision/diagnose_kiosk.sh

# Backup
sudo /opt/credvision/backup_kiosk.sh

# Gerenciar usuários
sudo /opt/credvision/create_admin.sh
```

## ✅ Funcionalidades
- 🖼️ Imagens (PNG, JPG, GIF)
- 🎥 Vídeos (MP4, AVI, MOV)
- 🌐 Sites e URLs
- 🔄 Rotação automática
- 📱 Acesso remoto
- 💾 Persistência total

**🎊 Sistema pronto para uso!**
