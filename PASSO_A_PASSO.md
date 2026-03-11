# CrediVision - Passo a Passo Completo

## 📋 Resumo do Sistema

**CrediVision Simple Kiosk** - Sistema de display digital que funciona sem iframe, abrindo sites em janelas reais do Firefox.

### ✅ Características:
- **Simple Kiosk**: Sem restrições de iframe
- **Suporte total**: Imagens, vídeos e URLs
- **Atualização automática**: Detecta mudanças em tempo real
- **Tela cheia real**: Firefox em modo kiosk
- **Rotação automática**: Entre diferentes conteúdos

---

## 🚀 Instalação do Zero

### 1. Preparar o Sistema
```bash
# Acessar diretório do projeto
cd /home/informa/Documentos/CrediVision

# Limpar arquivos antigos (opcional)
sudo bash cleanup_old_files.sh
```

### 2. Executar Instalação
```bash
# Tornar executável
chmod +x crevision_manager.sh

# Executar menu de instalação
sudo bash crevision_manager.sh
```

### 3. No Menu, Selecionar:
```
1) Instalar do Zero
```

### 4. Aguardar Instalação
- **Tempo estimado**: 10-15 minutos
- **Processo automático**: Instala tudo necessário
- **Sem intervenção manual**

### 5. Reiniciar Sistema
```bash
sudo reboot
```

### 6. Acessar Sistema
- **URL**: http://IP_DO_SERVIDOR:5000
- **Login**: admin / admin123
- **⚠️ IMPORTANTE**: Troque a senha imediatamente!

---

## 🔄 Atualização do Sistema

### 1. Executar Gerenciador
```bash
sudo bash crevision_manager.sh
```

### 2. Selecionar Opção:
```
2) Atualizar Sistema
```

### 3. Processo Automático:
- Atualiza pacotes do sistema
- Reconstrói imagem Docker (sem cache)
- Reinicia serviços

---

## 🗑️ Remoção Completa

### 1. Executar Gerenciador
```bash
sudo bash crevision_manager.sh
```

### 2. Selecionar Opção:
```
3) Remover Sistema
```

### 3. Confirmação:
- Digite "SIM" para confirmar
- Sistema faz backup antes de remover
- Remove tudo completamente

---

## 🎛️ Gerenciamento Diário

### Menu Principal
```bash
sudo bash crevision_manager.sh
```

### Opções Disponíveis:

#### 4) Gerenciar Serviços
- **4.1** Status de todos os serviços
- **4.2** Iniciar todos os serviços
- **4.3** Parar todos os serviços
- **4.4** Reiniciar todos os serviços
- **4.5** Ver logs da aplicação
- **4.6** Ver logs do kiosk
- **4.7** Ver logs do auto-update

#### 5) Testar Sistema
- **5.1** Testar API
- **5.2** Testar Kiosk (modo debug)
- **5.3** Testar Auto-Update
- **5.4** Testar Mídia (imagens/vídeos)

#### 6) Backup e Restore
- **6.1** Criar Backup
- **6.2** Listar Backups
- **6.3** Restaurar Backup

#### 7) Diagnóstico
- Verificação completa do sistema
- Status de todos os componentes
- Informações detalhadas

#### 8) Informações do Sistema
- URLs de acesso
- Comandos úteis
- Como funciona

---

## 📝 Uso do Sistema

### 1. Adicionar Conteúdo
1. Acesse: http://IP:5000
2. Faça login
3. Clique em "Abas"
4. "Adicionar Nova Aba"
5. Preencha:
   - **Nome**: Nome exibido
   - **Tipo**: URL, Imagem ou Vídeo
   - **URL/Caminho**: Endereço ou arquivo
   - **Duração**: Tempo em segundos
6. Salve

### 2. Atualização Automática
- **Detecção**: Até 5 segundos após salvar
- **Reinício**: Automático do kiosk
- **Notificação**: "Kiosk atualizado automaticamente"
- **Log**: /tmp/credivision_auto_update.log

### 3. Monitoramento
```bash
# Ver status em tempo real
sudo bash crevision_manager.sh
 opção 4.1

# Ver logs
sudo journalctl -u credivision-kiosk.service -f

# Ver logs de atualização
sudo tail -f /tmp/credivision_auto_update.log
```

---

## 🛠️ Comandos Rápidos

### Status
```bash
sudo bash crevision_manager.sh
# opção 4.1
```

### Logs
```bash
# Aplicação
sudo docker logs credivision-app -f

# Kiosk
sudo journalctl -u credivision-kiosk.service -f

# Auto-Update
sudo journalctl -u credivision-auto-update.service -f
```

### Reiniciar
```bash
sudo bash crevision_manager.sh
# opção 4.4
```

### Backup
```bash
sudo bash crevision_manager.sh
# opção 6.1
```

---

## 🚨 Solução de Problemas

### Problema: Kiosk não inicia
```bash
# Ver status
sudo bash crevision_manager.sh
# opção 4.1

# Reiniciar serviços
sudo bash crevision_manager.sh
# opção 4.4
```

### Problema: Atualização automática não funciona
```bash
# Testar auto-update
sudo bash crevision_manager.sh
# opção 5.3

# Reiniciar serviço
sudo systemctl restart credivision-auto-update.service
```

### Problema: API não responde
```bash
# Testar API
sudo bash crevision_manager.sh
# opção 5.1

# Ver container Docker
docker ps | grep credivision-app
```

### Problema: Firefox não abre
```bash
# Verificar instalação
firefox --version

# Instalar se necessário
sudo apt install firefox
```

---

## 📁 Estrutura de Arquivos

### Essenciais (mantidos após limpeza):
```
crevision_manager.sh          # Script principal
app_no_db.py                  # Aplicação Flask
Dockerfile.production         # Imagem Docker
docker-compose.production.yml # Config Docker
auto_update_kiosk.py          # Atualização automática
simple_kiosk_enhanced.sh      # Kiosk melhorado
test_media.sh                 # Teste de mídia
force_stop_all.sh             # Parada forçada
requirements.txt              # Dependências Python
templates/                    # Templates HTML
```

### Diretórios de Dados:
```
/home/informa/Documents/
├── kiosk-data/                # Configurações JSON
│   ├── tabs.json             # Abas de conteúdo
│   ├── users.json            # Usuários
│   └── logs.json             # Logs
├── kiosk-media/               # Arquivos de mídia
│   ├── images/               # Imagens
│   └── videos/               # Vídeos
└── kiosk-backups/             # Backups automáticos
```

---

## 🔄 Fluxo Completo

### Instalação Inicial:
1. `sudo bash crevision_manager.sh`
2. Opção `1` (Instalar do Zero)
3. Aguardar 15 minutos
4. `sudo reboot`
5. Acessar http://IP:5000
6. Trocar senha
7. Adicionar conteúdo

### Uso Diário:
1. Adicionar/editar conteúdo via web
2. Sistema atualiza automaticamente
3. Monitorar via `crevision_manager.sh`

### Manutenção:
1. `sudo bash crevision_manager.sh`
2. Opção `7` (Diagnóstico)
3. Verificar status geral

---

## 🎯 Dicas Importantes

### ✅ Boas Práticas:
- **Troque a senha** do admin imediatamente
- **Faça backup** antes de atualizar
- **Monitore os logs** regularmente
- **Teste em modo debug** antes de produção

### ⚠️ Cuidados:
- **Não desligue** durante atualização
- **Verifique espaço** em disco (>5GB)
- **Use apenas** o script principal
- **Não edite** arquivos manualmente

### 🔍 Monitoramento:
- **API**: http://IP:5000/api/config
- **Logs**: `/tmp/credivision_auto_update.log`
- **Status**: `sudo bash crevision_manager.sh` opção 4.1

---

## 📞 Suporte

### Comandos de Diagnóstico:
```bash
# Diagnóstico completo
sudo bash crevision_manager.sh
# opção 7

# Ver tudo
sudo bash crevision_manager.sh
# opção 8
```

### Logs Importantes:
```bash
# Sistema
sudo journalctl -u credivision-* -f

# Aplicação
sudo docker logs credivision-app -f

# Atualização
sudo tail -f /tmp/credivision_auto_update.log
```

---

## 🚀 Resumo Final

**Um único comando para tudo:**
```bash
sudo bash crevision_manager.sh
```

**Menu intuitivo com todas as opções:**
- Instalação do zero
- Atualização automática
- Remoção completa
- Gerenciamento de serviços
- Testes e diagnóstico
- Backup e restore

**Sistema simples, robusto e automático!**
