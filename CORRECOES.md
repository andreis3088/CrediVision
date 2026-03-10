# Correções Aplicadas ao Sistema CrediVision

## Problemas Identificados e Corrigidos

### 1. Erro de Nomenclatura de Rotas

**Problema:**
```
BuildError: Could not build url for endpoint 'logs_view'. Did you mean 'logs_list' instead?
```

**Causa:**
Os templates `base.html` e `dashboard.html` estavam usando `url_for('logs_view')`, mas a rota no `app_no_db.py` está definida como `logs_list`.

**Correção:**
- Arquivo: `templates/base.html` (linha 505)
  - Antes: `url_for('logs_view')`
  - Depois: `url_for('logs_list')`

- Arquivo: `templates/dashboard.html` (linha 83)
  - Antes: `url_for('logs_view')`
  - Depois: `url_for('logs_list')`

### 2. Erro no Dockerfile

**Problema:**
```
ERROR: failed to solve: "/static": not found
```

**Causa:**
O `Dockerfile.production` tentava copiar a pasta `static/` que não existe no projeto (CSS/JS estão inline nos templates).

**Correção:**
- Arquivo: `Dockerfile.production` (linha 22)
  - Removida linha: `COPY static/ static/`

## Rotas Disponíveis no Sistema

Todas as rotas definidas em `app_no_db.py`:

### Autenticação
- `/` → `index()` - Redireciona para login
- `/login` → `login()` - Página de login
- `/logout` → `logout()` - Logout

### Dashboard
- `/dashboard` → `dashboard()` - Dashboard principal

### Abas/Conteúdo
- `/tabs` → `tabs_list()` - Listar abas
- `/tabs/add` → `tab_add()` - Adicionar aba
- `/tabs/<id>/toggle` → `tab_toggle()` - Ativar/desativar
- `/tabs/<id>/delete` → `tab_delete()` - Excluir aba
- `/tabs/<id>/edit` → `tab_edit()` - Editar aba
- `/tabs/delete_file/<id>` → `delete_file_only()` - Excluir apenas arquivo
- `/tabs/reorder` → `tab_reorder()` - Reordenar abas

### Usuários
- `/users` → `users_list()` - Listar usuários
- `/users/add` → `user_add()` - Adicionar usuário
- `/users/<id>/delete` → `user_delete()` - Excluir usuário

### Logs
- `/logs` → `logs_list()` - Listar logs

### Display
- `/display` → `display()` - Tela do kiosk

### API
- `/api/config` → `api_config()` - Configuração para kiosk
- `/api/status` → `api_status()` - Heartbeat do kiosk
- `/media/<filename>` → `serve_media()` - Servir arquivos de mídia

## Como Atualizar o Sistema

### Opção 1: Script Automatizado (Recomendado)

```bash
cd /caminho/para/credivision
chmod +x atualizar.sh
sudo bash atualizar.sh
```

O script irá:
1. Parar serviços
2. Parar container Docker
3. Remover imagem antiga
4. Construir nova imagem
5. Iniciar serviços
6. Verificar funcionamento

### Opção 2: Manual

```bash
# 1. Parar serviços
sudo systemctl stop credivision-kiosk.service
sudo systemctl stop credivision-app.service

# 2. Parar e remover container
cd /caminho/para/credivision
docker compose down
docker rmi credivision-app

# 3. Construir nova imagem
docker build -f Dockerfile.production -t credivision-app .

# 4. Iniciar aplicação
sudo systemctl start credivision-app.service

# 5. Aguardar 10 segundos
sleep 10

# 6. Testar API
curl http://localhost:5000/api/config

# 7. Iniciar kiosk
sudo systemctl start credivision-kiosk.service
```

## Verificação Pós-Atualização

### 1. Verificar Status dos Serviços

```bash
sudo bash manage.sh status
```

Ou manualmente:

```bash
sudo systemctl status credivision-app.service
sudo systemctl status credivision-kiosk.service
docker ps | grep credivision-app
```

### 2. Verificar Logs

```bash
# Logs da aplicação
docker logs credivision-app

# Logs do kiosk
sudo journalctl -u credivision-kiosk.service -n 50

# Ou usar script de gerenciamento
sudo bash manage.sh logs
sudo bash manage.sh logs-kiosk
```

### 3. Testar Interface Admin

```bash
# Testar API
curl http://localhost:5000/api/config

# Acessar no navegador
# http://IP_DO_SERVIDOR:5000
```

Fazer login e verificar:
- Dashboard carrega sem erros
- Menu de navegação funciona (Dashboard, Abas, Usuários, Logs)
- Todas as páginas carregam corretamente

### 4. Verificar Kiosk

O Firefox deve estar exibindo o conteúdo em tela cheia.

```bash
# Verificar processo Firefox
ps aux | grep firefox | grep kiosk

# Se não estiver rodando, reiniciar
sudo systemctl restart credivision-kiosk.service
```

## Solução de Problemas

### Container não inicia

```bash
# Ver logs detalhados
docker logs credivision-app

# Verificar se porta está em uso
sudo netstat -tlnp | grep 5000

# Tentar iniciar manualmente
cd /caminho/para/credivision
docker compose up
```

### Kiosk não exibe

```bash
# Verificar serviço
sudo systemctl status credivision-kiosk.service

# Ver logs
sudo journalctl -u credivision-kiosk.service -n 50

# Reiniciar
sudo systemctl restart credivision-kiosk.service
```

### Erro ao construir imagem Docker

```bash
# Verificar se todos os arquivos necessários existem
ls -la app_no_db.py
ls -la templates/
ls -la requirements.txt
ls -la Dockerfile.production

# Limpar cache do Docker
docker system prune -a

# Tentar build novamente
docker build -f Dockerfile.production -t credivision-app .
```

### Interface admin mostra erro 500

```bash
# Ver logs da aplicação
docker logs credivision-app

# Verificar se arquivos JSON existem
ls -la ~/Documents/kiosk-data/

# Se necessário, recriar arquivos
mkdir -p ~/Documents/kiosk-data
echo "[]" > ~/Documents/kiosk-data/tabs.json
echo "[]" > ~/Documents/kiosk-data/users.json
echo "[]" > ~/Documents/kiosk-data/logs.json

# Recriar usuário admin
sudo bash manage.sh user-create
```

## Arquivos Modificados

1. `templates/base.html` - Corrigido `logs_view` → `logs_list`
2. `templates/dashboard.html` - Corrigido `logs_view` → `logs_list`
3. `Dockerfile.production` - Removida cópia de pasta `static/`
4. `atualizar.sh` - Novo script de atualização

## Checklist de Verificação

Após atualização, verificar:

- [ ] Container Docker está rodando: `docker ps`
- [ ] Serviço app está ativo: `systemctl status credivision-app.service`
- [ ] Serviço kiosk está ativo: `systemctl status credivision-kiosk.service`
- [ ] API responde: `curl http://localhost:5000/api/config`
- [ ] Interface admin acessível: http://IP_DO_SERVIDOR:5000
- [ ] Login funciona com admin/admin123
- [ ] Dashboard carrega sem erros
- [ ] Menu de navegação funciona (todas as páginas)
- [ ] Página de Logs acessível
- [ ] Firefox kiosk exibindo conteúdo
- [ ] Sem erros nos logs: `docker logs credivision-app`

## Suporte

Se problemas persistirem:

```bash
# Executar diagnóstico completo
sudo bash manage.sh diagnose

# Coletar logs
docker logs credivision-app > app-logs.txt
sudo journalctl -u credivision-kiosk.service -n 100 > kiosk-logs.txt
sudo journalctl -u credivision-app.service -n 100 > service-logs.txt
```

Envie os arquivos de log para análise.
