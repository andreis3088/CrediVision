# Sistema Kiosk CrediVision

Sistema automatizado de exibição em modo kiosk para TVs e monitores com administração via web e armazenamento local de arquivos.

## Visão Geral

O CrediVision é uma solução completa de kiosk projetada para exibir conteúdo rotativo em TVs e monitores. O sistema roda no Ubuntu com Docker, inicia automaticamente no boot e exibe conteúdo no Firefox em modo tela cheia.

### Casos de Uso

- Lobbies corporativos e áreas de recepção
- Displays de lojas e promoções no varejo
- Salas de espera em clínicas e hospitais
- Instituições educacionais
- Instalações industriais
- Painéis de informação pública

## Funcionalidades

### Exibição de Conteúdo

- Exibição de URLs/Sites via iframe
- Exibição de imagens (PNG, JPG, JPEG, GIF)
- Reprodução de vídeos (MP4, AVI, MOV, WEBM)
- Rotação automática de conteúdo
- Duração configurável por item
- Firefox em modo kiosk tela cheia

### Administração

- Interface administrativa via web
- Autenticação e autorização de usuários
- Gerenciamento de conteúdo (adicionar, editar, excluir, reordenar)
- Suporte a upload de arquivos (máx 100MB)
- Registro de atividades e auditoria
- Acesso remoto de qualquer dispositivo na rede

### Armazenamento

- Armazenamento baseado em arquivos (sem banco de dados)
- Arquivos JSON para configuração
- Armazenamento local de mídia na pasta Documentos
- Backups automáticos diários
- Persistência completa de dados entre reinicializações

### Automação

- Inicialização automática com o Ubuntu
- Container Docker para isolamento da aplicação
- Serviços systemd para gerenciamento
- Delay de 30 segundos antes da exibição do kiosk
- Reinicialização automática em caso de falha
- Monitoramento de saúde

## Arquitetura

### Componentes

- Backend: Flask (Python)
- Frontend: HTML5, CSS3, JavaScript
- Container: Docker com Docker Compose
- Exibição: Firefox em modo kiosk
- Armazenamento: Arquivos JSON + sistema de arquivos local
- Serviços: Systemd para auto-inicialização

### Estrutura de Diretórios

```
/home/usuario/Documents/
├── kiosk-data/           # Arquivos de configuração JSON
│   ├── tabs.json        # Configuração das abas de conteúdo
│   ├── users.json       # Contas de usuário
│   └── logs.json        # Logs de atividade
├── kiosk-media/          # Arquivos de mídia enviados
│   ├── images/          # Arquivos de imagem
│   └── videos/          # Arquivos de vídeo
└── kiosk-backups/        # Backups automáticos
```

## Início Rápido

### Requisitos

- Ubuntu 20.04 LTS ou mais recente (edição Desktop)
- Mínimo 4GB RAM (8GB recomendado)
- Mínimo 20GB de espaço livre em disco
- Conexão com internet para instalação
- Acesso sudo/root

### Instalação

1. Clone o repositório:
```bash
git clone https://github.com/SEU-USUARIO/credivision.git
cd credivision
```

2. Execute o script de instalação:
```bash
chmod +x install.sh
sudo bash install.sh
```

3. Reinicie o sistema:
```bash
sudo reboot
```

O sistema iniciará automaticamente no boot.

### Primeiro Acesso

1. Abra o navegador e acesse: http://IP_DO_SERVIDOR:5000
2. Faça login com as credenciais padrão:
   - Usuário: admin
   - Senha: admin123
3. Altere a senha padrão imediatamente
4. Configure sua primeira aba de conteúdo

## Documentação

- **INSTALACAO.md** - Instruções detalhadas de instalação
- **OPERACAO.md** - Guia de operação e manutenção diária
- **manage.sh** - Script de gerenciamento do sistema

## Comandos de Gerenciamento

O script manage.sh fornece tarefas comuns de gerenciamento:

```bash
# Iniciar serviços
sudo bash manage.sh start

# Parar serviços
sudo bash manage.sh stop

# Reiniciar serviços
sudo bash manage.sh restart

# Ver status
sudo bash manage.sh status

# Ver logs
sudo bash manage.sh logs

# Criar backup
sudo bash manage.sh backup

# Restaurar backup
sudo bash manage.sh restore

# Criar usuário
sudo bash manage.sh user-create

# Listar usuários
sudo bash manage.sh user-list

# Executar diagnóstico
sudo bash manage.sh diagnose

# Atualizar aplicação
sudo bash manage.sh update
```

## Comportamento do Sistema

### Sequência de Boot

1. Ubuntu inicia (15-20 segundos)
2. Serviço Docker inicia automaticamente
3. Container da aplicação CrediVision inicia
4. Delay de 30 segundos
5. Firefox abre em modo kiosk
6. Conteúdo é exibido automaticamente

### Rotação de Conteúdo

- Conteúdo rotaciona baseado na duração configurada
- Cada aba exibe pelo tempo especificado
- Rotação continua indefinidamente
- Alterações na interface admin aplicam imediatamente

### Persistência de Dados

Todos os dados são armazenados em ~/Documents/ e persistem entre:
- Reinicializações do sistema
- Reinicializações da aplicação
- Reconstruções do container
- Atualizações do sistema

## Configuração

### Configuração de Porta

Porta padrão: 5000

Para alterar a porta, edite docker-compose.yml:
```yaml
ports:
  - "NOVA_PORTA:5000"
```

### Delay do Kiosk

Delay padrão: 30 segundos

Para alterar o delay, edite /etc/systemd/system/credivision-kiosk.service:
```
ExecStartPre=/bin/sleep NOVO_DELAY
```

### Auto-Login

Para habilitar login automático sem senha:

Edite /etc/gdm3/custom.conf:
```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=SEU_USUARIO
```

## Formatos de Arquivo Suportados

### Imagens
- PNG
- JPG/JPEG
- GIF

### Vídeos
- MP4
- AVI
- MOV
- WEBM

Tamanho máximo de arquivo: 100MB

## Segurança

### Credenciais Padrão

Usuário: admin
Senha: admin123

IMPORTANTE: Altere a senha padrão imediatamente após a instalação.

### Recomendações de Segurança

1. Altere a senha padrão do admin
2. Use senhas fortes e únicas
3. Limite o acesso de rede à interface admin
4. Mantenha o sistema atualizado
5. Habilite o firewall
6. Faça backups regulares
7. Monitore os logs de acesso

## Backup e Restauração

### Backups Automáticos

- Frequência: Diariamente à meia-noite
- Local: ~/Documents/kiosk-backups/
- Retenção: 7 dias
- Inclui: Todos os arquivos de dados e mídia

### Backup Manual

```bash
sudo bash manage.sh backup
```

### Restauração

```bash
sudo bash manage.sh restore
```

## Solução de Problemas

### Kiosk Não Está Exibindo

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

### Ver Logs

```bash
sudo bash manage.sh logs
sudo bash manage.sh logs-kiosk
```

### Executar Diagnóstico

```bash
sudo bash manage.sh diagnose
```

## Suporte

Para informações detalhadas:
- Instalação: Veja INSTALACAO.md
- Operações: Veja OPERACAO.md
- Problemas: Verifique a página de issues no GitHub

## Licença

[Especifique sua licença aqui]

## Contribuindo

[Especifique diretrizes de contribuição aqui]
