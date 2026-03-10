# CrediVision - Resumo Completo do Sistema

## Visão Geral

Sistema kiosk completo para exibição de conteúdo rotativo em TVs e monitores, rodando em Ubuntu com Docker, com administração via web e armazenamento local sem banco de dados.

## Arquivos Principais

### Scripts de Instalação e Gerenciamento

**install.sh** (600 linhas)
- Instalação automatizada completa
- Atualização do Ubuntu
- Instalação do Docker
- Criação de estrutura de diretórios
- Configuração de serviços systemd
- Build de imagem Docker
- Criação de usuário admin
- Configuração de firewall

**manage.sh** (400 linhas)
- Comandos: start, stop, restart, status
- Visualização de logs
- Backup e restore
- Gerenciamento de usuários
- Diagnóstico do sistema
- Atualização da aplicação

### Configuração Docker

**Dockerfile.production**
- Imagem Python 3.11-slim
- Dependências mínimas
- Health check configurado
- Porta 5000 exposta

**docker-compose.production.yml**
- Serviço credivision-app
- Volumes para dados e mídia
- Variáveis de ambiente
- Restart automático

### Aplicação

**app_no_db.py** (478 linhas)
- Backend Flask
- Armazenamento em JSON
- Autenticação SHA-256
- Upload de arquivos
- API REST
- Logs de auditoria

### Templates HTML

- base.html - Template base
- login.html - Tela de login
- dashboard.html - Dashboard principal
- tabs.html - Gerenciamento de abas
- users.html - Gerenciamento de usuários
- logs.html - Visualização de logs
- display.html - Exibição kiosk

### Documentação em PT-BR

**LEIAME.md**
- Visão geral do sistema
- Funcionalidades
- Início rápido
- Comandos de gerenciamento
- Configuração
- Solução de problemas

**INSTALACAO.md**
- Requisitos do sistema
- Pré-instalação
- Instalação automatizada
- Instalação manual
- Configuração pós-instalação
- Verificação
- Troubleshooting

**OPERACAO.md**
- Operações diárias
- Gerenciamento de conteúdo
- Gerenciamento de usuários
- Manutenção
- Backup e restauração
- Monitoramento
- Configuração avançada

**GUIA_RAPIDO.md**
- Instalação rápida
- Primeiro acesso
- Comandos principais
- Solução rápida de problemas

## Estrutura de Dados

### Diretórios Persistentes

```
/home/usuario/Documents/
├── kiosk-data/
│   ├── tabs.json       # Configuração das abas
│   ├── users.json      # Usuários do sistema
│   └── logs.json       # Logs de auditoria
├── kiosk-media/
│   ├── images/         # Imagens enviadas
│   └── videos/         # Vídeos enviados
└── kiosk-backups/      # Backups automáticos
```

### Serviços Systemd

```
/etc/systemd/system/
├── credivision-app.service      # Aplicação Docker
├── credivision-kiosk.service    # Firefox kiosk
├── credivision-backup.service   # Serviço de backup
└── credivision-backup.timer     # Timer diário
```

## Funcionamento

### Sequência de Inicialização

1. Ubuntu inicia (15-20s)
2. Docker service inicia
3. credivision-app.service inicia container
4. Aplicação Flask fica pronta (porta 5000)
5. Delay de 30 segundos
6. credivision-kiosk.service inicia Firefox
7. Firefox exibe http://localhost:5000/display
8. Conteúdo rotaciona automaticamente

### Fluxo de Conteúdo

**Adicionar Conteúdo:**
1. Admin acessa interface web
2. Faz login
3. Adiciona aba (URL, imagem ou vídeo)
4. Define duração
5. Salva configuração

**Processamento:**
1. Backend valida dados
2. Para arquivos: salva em ~/Documents/kiosk-media/
3. Atualiza tabs.json
4. Registra ação em logs.json

**Exibição:**
1. Display kiosk consulta /api/config
2. Recebe lista de abas ativas
3. Exibe cada aba pela duração configurada
4. Rotaciona continuamente

### Tipos de Conteúdo

**URL/Site:**
- Exibido em iframe
- Duração configurável
- Atualização automática

**Imagem:**
- Formatos: PNG, JPG, JPEG, GIF
- Máximo: 100MB
- Armazenada localmente

**Vídeo:**
- Formatos: MP4, AVI, MOV, WEBM
- Máximo: 100MB
- Reprodução automática

## Instalação

### Método Automatizado

```bash
# Clonar repositório
git clone https://github.com/SEU-USUARIO/credivision.git
cd credivision

# Executar instalação
chmod +x install.sh
sudo bash install.sh

# Reiniciar
sudo reboot
```

### Primeiro Acesso

```
URL: http://IP_DO_SERVIDOR:5000
Usuário: admin
Senha: admin123
```

IMPORTANTE: Trocar senha padrão imediatamente.

## Gerenciamento

### Comandos Principais

```bash
# Status do sistema
sudo bash manage.sh status

# Iniciar serviços
sudo bash manage.sh start

# Parar serviços
sudo bash manage.sh stop

# Reiniciar serviços
sudo bash manage.sh restart

# Ver logs
sudo bash manage.sh logs

# Ver logs do kiosk
sudo bash manage.sh logs-kiosk

# Criar backup
sudo bash manage.sh backup

# Restaurar backup
sudo bash manage.sh restore

# Criar usuário
sudo bash manage.sh user-create

# Listar usuários
sudo bash manage.sh user-list

# Diagnóstico completo
sudo bash manage.sh diagnose

# Atualizar aplicação
sudo bash manage.sh update
```

### Gerenciamento de Conteúdo

**Via Interface Web:**
1. Acessar http://IP_DO_SERVIDOR:5000
2. Login com credenciais
3. Navegar para "Abas / Conteúdo"
4. Adicionar, editar, excluir ou reordenar abas
5. Ativar/desativar abas conforme necessário

**Operações:**
- Adicionar nova aba
- Editar aba existente
- Excluir aba (remove arquivo do disco)
- Reordenar por drag-and-drop
- Ativar/desativar temporariamente

## Backup e Restauração

### Backup Automático

- Frequência: Diariamente à meia-noite
- Local: ~/Documents/kiosk-backups/
- Retenção: 7 dias
- Conteúdo: Todos os dados JSON e arquivos de mídia

### Backup Manual

```bash
sudo bash manage.sh backup
```

Arquivo criado: manual_backup_TIMESTAMP.tar.gz

### Restauração

```bash
sudo bash manage.sh restore
```

Processo:
1. Lista backups disponíveis
2. Seleciona backup para restaurar
3. Cria backup do estado atual
4. Para serviços
5. Extrai backup
6. Corrige permissões
7. Reinicia serviços

## Monitoramento

### Verificação de Saúde

```bash
# Diagnóstico completo
sudo bash manage.sh diagnose
```

Verifica:
- Informações do sistema
- Status dos serviços
- Status do Docker
- Status do container
- Diretórios e arquivos
- Rede e API
- Firefox kiosk
- Erros recentes

### Logs

```bash
# Logs da aplicação
sudo bash manage.sh logs

# Logs do kiosk
sudo bash manage.sh logs-kiosk

# Logs do systemd
sudo journalctl -u credivision-app.service -f
sudo journalctl -u credivision-kiosk.service -f

# Logs do Docker
docker logs credivision-app
docker logs -f credivision-app
```

## Solução de Problemas

### Kiosk Não Exibe

```bash
sudo systemctl status credivision-kiosk.service
sudo systemctl restart credivision-kiosk.service
```

### Interface Admin Não Acessível

```bash
sudo systemctl status credivision-app.service
docker ps
sudo systemctl restart credivision-app.service
```

### Conteúdo Não Rotaciona

1. Verificar abas ativas na interface admin
2. Verificar console JavaScript (F12)
3. Reiniciar kiosk: `sudo systemctl restart credivision-kiosk.service`

### Upload Falha

1. Verificar tamanho (máx 100MB)
2. Verificar formato (tipos suportados)
3. Verificar espaço em disco: `df -h`
4. Verificar permissões: `ls -la ~/Documents/kiosk-media/`

### Diagnóstico Geral

```bash
# Executar diagnóstico completo
sudo bash manage.sh diagnose

# Ver status detalhado
sudo bash manage.sh status

# Verificar logs
sudo bash manage.sh logs
```

## Configuração

### Alterar Porta (padrão: 5000)

Editar docker-compose.yml:
```yaml
ports:
  - "NOVA_PORTA:5000"
```

Editar credivision-kiosk.service:
```
ExecStart=/usr/bin/firefox --kiosk http://localhost:NOVA_PORTA/display ...
```

Reiniciar:
```bash
sudo systemctl daemon-reload
sudo systemctl restart credivision-app.service
sudo systemctl restart credivision-kiosk.service
```

### Alterar Delay do Kiosk (padrão: 30s)

Editar /etc/systemd/system/credivision-kiosk.service:
```
ExecStartPre=/bin/sleep NOVO_DELAY
```

Reiniciar:
```bash
sudo systemctl daemon-reload
sudo systemctl restart credivision-kiosk.service
```

### Configurar Auto-Login

Editar /etc/gdm3/custom.conf:
```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=SEU_USUARIO
```

Reiniciar GDM:
```bash
sudo systemctl restart gdm3
```

## Segurança

### Credenciais Padrão

```
Usuário: admin
Senha: admin123
```

IMPORTANTE: Alterar imediatamente após instalação.

### Recomendações

1. Trocar senha padrão do admin
2. Usar senhas fortes e únicas
3. Limitar acesso de rede à interface admin
4. Manter sistema atualizado
5. Fazer backups regulares
6. Monitorar logs de acesso
7. Usar firewall (UFW configurado automaticamente)

### Autenticação

- Hash SHA-256 com salt
- Sessões baseadas em cookies
- Timeout configurável (padrão: 3600s)
- Controle de tentativas de login
- Bloqueio de conta após múltiplas falhas

## Performance

### Recursos Típicos

- CPU: 5-10% (idle), 20-30% (vídeo)
- RAM: 500MB (app), 500MB (Firefox)
- Disco: 100MB (app), variável (mídia)
- Rede: Mínima (apenas local)

### Limites

- Abas: Sem limite rígido (testado até 100)
- Tamanho de arquivo: 100MB por arquivo
- Armazenamento total: Limitado pelo disco
- Usuários simultâneos: 10-20 (interface admin)

### Otimização

1. Comprimir imagens antes do upload
2. Usar codecs apropriados para vídeos
3. Limitar número de abas ativas
4. Definir durações razoáveis
5. Monitorar espaço em disco
6. Limpar arquivos não utilizados regularmente

## Manutenção

### Cronograma Recomendado

**Diariamente:**
- Verificar display funcionando
- Verificar rotação de conteúdo
- Monitorar mensagens de erro

**Semanalmente:**
- Revisar logs do sistema
- Verificar espaço em disco
- Verificar backups
- Atualizar conteúdo

**Mensalmente:**
- Atualizar pacotes do sistema
- Limpar logs antigos
- Remover mídia não utilizada
- Testar restauração de backup
- Revisar acessos de usuários

**Trimestralmente:**
- Atualização completa do sistema
- Auditoria de segurança
- Revisão de performance
- Atualização de documentação

## Requisitos do Sistema

### Mínimos

- OS: Ubuntu 20.04 LTS Desktop
- CPU: 2 núcleos
- RAM: 4GB
- Armazenamento: 20GB livre
- Rede: Ethernet ou WiFi
- Display: Compatível com HDMI

### Recomendados

- OS: Ubuntu 22.04 LTS Desktop
- CPU: 4 núcleos
- RAM: 8GB
- Armazenamento: 50GB livre
- Rede: Gigabit Ethernet
- Display: Full HD (1920x1080)

## Características Principais

### Automação

- Inicialização automática no boot
- Rotação automática de conteúdo
- Backups automáticos diários
- Reinicialização automática em falhas
- Limpeza automática de backups antigos

### Persistência

- Dados em ~/Documents/
- Sobrevive a reinicializações
- Sobrevive a atualizações
- Sobrevive a reconstruções de container
- Sem perda de dados em queda de energia

### Gerenciamento

- Administração via web
- Script de gerenciamento CLI
- Logs completos
- Diagnóstico do sistema
- Backup e restauração

### Flexibilidade

- Porta configurável
- Delays configuráveis
- Durações configuráveis
- Limites de arquivo configuráveis
- Cronograma de backup configurável

## Suporte

### Documentação

- LEIAME.md - Visão geral
- INSTALACAO.md - Instalação detalhada
- OPERACAO.md - Operação diária
- GUIA_RAPIDO.md - Referência rápida
- RESUMO_SISTEMA.md - Este documento

### Scripts

- install.sh - Instalação automatizada
- manage.sh - Gerenciamento do sistema

### Logs

- Aplicação: journalctl -u credivision-app
- Kiosk: journalctl -u credivision-kiosk
- Docker: docker logs credivision-app
- Sistema: /var/log/syslog

### Comandos Úteis

```bash
# Status
sudo bash manage.sh status

# Diagnóstico
sudo bash manage.sh diagnose

# Logs
sudo bash manage.sh logs

# Ajuda
sudo bash manage.sh help
```

## Conclusão

O CrediVision é um sistema kiosk completo, pronto para produção, projetado para confiabilidade e facilidade de uso. O sistema gerencia todos os aspectos de exibição de conteúdo automaticamente, requer manutenção mínima e fornece ferramentas abrangentes de gerenciamento. Todos os dados são armazenados localmente com backups automáticos, garantindo que nenhum dado seja perdido. O sistema está totalmente documentado em português brasileiro com guias detalhados de instalação e operação.
