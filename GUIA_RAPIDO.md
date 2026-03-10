# CrediVision - Guia Rápido

## O que é o CrediVision?

Sistema automatizado para exibir conteúdo rotativo (sites, imagens, vídeos) em TVs e monitores. Ideal para lobbies, recepções, lojas e áreas públicas.

## Instalação Rápida

### Requisitos
- Ubuntu 20.04+ Desktop
- 4GB RAM mínimo
- 20GB espaço livre
- Acesso sudo

### Instalar

```bash
# 1. Clonar repositório
git clone https://github.com/SEU-USUARIO/credivision.git
cd credivision

# 2. Executar instalação
chmod +x install.sh
sudo bash install.sh

# 3. Reiniciar
sudo reboot
```

Pronto! O sistema inicia automaticamente.

## Primeiro Acesso

```
URL: http://IP_DO_SERVIDOR:5000
Usuário: admin
Senha: admin123
```

**IMPORTANTE:** Troque a senha padrão imediatamente!

## Adicionar Conteúdo

### Via Interface Web

1. Acesse http://IP_DO_SERVIDOR:5000
2. Faça login
3. Vá em "Abas / Conteúdo"
4. Clique "Nova Aba"
5. Escolha tipo:
   - **URL**: Digite endereço do site
   - **Imagem**: Faça upload (PNG, JPG, GIF)
   - **Vídeo**: Faça upload (MP4, AVI, MOV, WEBM)
6. Defina duração em segundos
7. Salve

## Comandos Principais

```bash
# Ver status
sudo bash manage.sh status

# Ver logs
sudo bash manage.sh logs

# Reiniciar
sudo bash manage.sh restart

# Parar
sudo bash manage.sh stop

# Iniciar
sudo bash manage.sh start

# Backup
sudo bash manage.sh backup

# Restaurar
sudo bash manage.sh restore

# Criar usuário
sudo bash manage.sh user-create

# Diagnóstico
sudo bash manage.sh diagnose
```

## Como Funciona

### Sequência de Boot
1. Ubuntu liga (15-20s)
2. Docker inicia automaticamente
3. Aplicação CrediVision sobe (30s)
4. Firefox abre em tela cheia (30s)
5. Conteúdo exibe automaticamente

### Rotação de Conteúdo
- Cada aba exibe pelo tempo configurado
- Rotação automática e contínua
- Alterações aplicam imediatamente

### Armazenamento
Tudo salvo em `~/Documents/`:
- `kiosk-data/` - Configurações JSON
- `kiosk-media/` - Imagens e vídeos
- `kiosk-backups/` - Backups automáticos

## Solução de Problemas

### Kiosk não exibe
```bash
sudo systemctl restart credivision-kiosk.service
```

### Interface admin não abre
```bash
sudo systemctl restart credivision-app.service
docker ps
```

### Ver erros
```bash
sudo bash manage.sh logs
sudo bash manage.sh diagnose
```

### Conteúdo não rotaciona
1. Verifique se abas estão ativas
2. Reinicie kiosk: `sudo systemctl restart credivision-kiosk.service`

## Configurações

### Alterar Porta (padrão: 5000)
Edite `docker-compose.yml`:
```yaml
ports:
  - "NOVA_PORTA:5000"
```

### Alterar Delay (padrão: 30s)
Edite `/etc/systemd/system/credivision-kiosk.service`:
```
ExecStartPre=/bin/sleep NOVO_DELAY
```

### Auto-Login
Edite `/etc/gdm3/custom.conf`:
```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=SEU_USUARIO
```

## Backup e Restauração

### Backup Automático
- Diário à meia-noite
- Últimos 7 dias mantidos
- Local: `~/Documents/kiosk-backups/`

### Backup Manual
```bash
sudo bash manage.sh backup
```

### Restaurar
```bash
sudo bash manage.sh restore
```

## Formatos Suportados

### Imagens
PNG, JPG, JPEG, GIF (máx 100MB)

### Vídeos
MP4, AVI, MOV, WEBM (máx 100MB)

## Estrutura de Arquivos

```
~/Documents/
├── kiosk-data/
│   ├── tabs.json      # Configuração das abas
│   ├── users.json     # Usuários
│   └── logs.json      # Logs
├── kiosk-media/
│   ├── images/        # Imagens
│   └── videos/        # Vídeos
└── kiosk-backups/     # Backups
```

## Manutenção

### Diária
- Verificar display funcionando
- Verificar rotação de conteúdo

### Semanal
- Revisar logs: `sudo bash manage.sh logs`
- Verificar espaço: `df -h`
- Atualizar conteúdo

### Mensal
- Atualizar sistema: `sudo apt update && sudo apt upgrade`
- Limpar arquivos antigos
- Testar backup: `sudo bash manage.sh restore`

## Segurança

1. Trocar senha padrão
2. Usar senhas fortes
3. Manter sistema atualizado
4. Fazer backups regulares
5. Monitorar logs

## Documentação Completa

- **LEIAME.md** - Visão geral completa
- **INSTALACAO.md** - Guia detalhado de instalação
- **OPERACAO.md** - Operação e manutenção
- **manage.sh** - Script de gerenciamento

## Suporte

Problemas? Execute:
```bash
sudo bash manage.sh diagnose
```

Verifique logs:
```bash
sudo bash manage.sh logs
```

Consulte documentação completa nos arquivos .md
