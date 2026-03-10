# Sistema Kiosk CrediVision - Guia de Operação e Manutenção

## Índice

1. [Operações Diárias](#operações-diárias)
2. [Gerenciamento de Conteúdo](#gerenciamento-de-conteúdo)
3. [Gerenciamento de Usuários](#gerenciamento-de-usuários)
4. [Manutenção do Sistema](#manutenção-do-sistema)
5. [Backup e Restauração](#backup-e-restauração)
6. [Monitoramento](#monitoramento)
7. [Solução de Problemas](#solução-de-problemas)

## Operações Diárias

### Iniciar o Sistema

O sistema inicia automaticamente quando o Ubuntu é ligado. Nenhuma intervenção manual é necessária.

Sequência de boot:
1. Ubuntu inicia (15-20 segundos)
2. Serviço Docker inicia automaticamente
3. Aplicação CrediVision inicia (delay de 30 segundos)
4. Firefox kiosk abre automaticamente (30 segundos após app)
5. Conteúdo é exibido na tela

### Parar o Sistema

Para parar o sistema de forma controlada:

```bash
sudo bash manage.sh stop
```

Isso para tanto o display kiosk quanto a aplicação.

### Reiniciar o Sistema

Para reiniciar o sistema:

```bash
sudo bash manage.sh restart
```

Ou reiniciar componentes individuais:

```bash
# Reiniciar apenas aplicação
sudo systemctl restart credivision-app.service

# Reiniciar apenas kiosk
sudo systemctl restart credivision-kiosk.service
```

### Verificar Status do Sistema

Para ver o status atual do sistema:

```bash
sudo bash manage.sh status
```

Exibe:
- Status dos serviços (ativo/inativo)
- Status do container Docker
- Status da porta de rede
- Uso de armazenamento
- Número de abas configuradas
- Número de usuários

### Visualizar Logs

Para ver logs da aplicação em tempo real:

```bash
sudo bash manage.sh logs
```

Para ver logs do kiosk:

```bash
sudo bash manage.sh logs-kiosk
```

Pressione Ctrl+C para sair da visualização de logs.

## Gerenciamento de Conteúdo

### Acessar Interface Admin

1. Abra navegador web em qualquer dispositivo na rede
2. Navegue para: http://IP_DO_SERVIDOR:5000
3. Faça login com credenciais admin

### Adicionar Conteúdo

#### Adicionar Aba de URL

1. Faça login na interface admin
2. Navegue para "Abas / Conteúdo"
3. Clique em "Nova Aba"
4. Selecione "URL (Site)" como tipo de conteúdo
5. Digite nome da aba (ex: "Dashboard da Empresa")
6. Digite URL (ex: https://exemplo.com)
7. Defina duração em segundos (ex: 300 para 5 minutos)
8. Clique em "Adicionar"

#### Adicionar Imagem

1. Navegue para "Abas / Conteúdo"
2. Clique em "Nova Aba"
3. Selecione "Arquivo (Imagem/Vídeo)" como tipo de conteúdo
4. Digite nome da aba (ex: "Banner Promocional")
5. Clique em "Escolher Arquivo" e selecione imagem
6. Formatos suportados: PNG, JPG, JPEG, GIF
7. Tamanho máximo: 100MB
8. Defina duração em segundos
9. Clique em "Adicionar"

Imagem é salva em: ~/Documents/kiosk-media/images/

#### Adicionar Vídeo

1. Navegue para "Abas / Conteúdo"
2. Clique em "Nova Aba"
3. Selecione "Arquivo (Imagem/Vídeo)" como tipo de conteúdo
4. Digite nome da aba (ex: "Vídeo do Produto")
5. Clique em "Escolher Arquivo" e selecione vídeo
6. Formatos suportados: MP4, AVI, MOV, WEBM
7. Tamanho máximo: 100MB
8. Defina duração em segundos
9. Clique em "Adicionar"

Vídeo é salvo em: ~/Documents/kiosk-media/videos/

### Editar Conteúdo

1. Navegue para "Abas / Conteúdo"
2. Encontre a aba para editar
3. Clique no botão editar (ícone de lápis)
4. Modifique nome, URL ou duração
5. Clique em "Salvar Alterações"

Nota: Não é possível alterar tipo de conteúdo ou arquivo após criação.

### Reordenar Conteúdo

As abas são exibidas na ordem mostrada na interface admin.

Para reordenar:
1. Navegue para "Abas / Conteúdo"
2. Arraste e solte abas na ordem desejada
3. Ordem salva automaticamente

### Ativar/Desativar Conteúdo

Para desabilitar temporariamente uma aba sem excluir:

1. Navegue para "Abas / Conteúdo"
2. Encontre a aba
3. Clique no botão ativar/desativar (ícone play/pause)
4. Abas inativas não são exibidas no kiosk

### Excluir Conteúdo

Para excluir uma aba:

1. Navegue para "Abas / Conteúdo"
2. Encontre a aba para excluir
3. Clique no botão excluir (ícone de lixeira)
4. Confirme exclusão

Para conteúdo baseado em arquivo (imagens/vídeos):
- Excluir a aba também exclui o arquivo do disco
- Esta ação não pode ser desfeita
- Certifique-se de ter backups se necessário

### Boas Práticas de Conteúdo

1. **Duração**: Defina durações apropriadas
   - Imagens estáticas: 15-30 segundos
   - Vídeos: Duração completa do vídeo + 5 segundos
   - URLs/Dashboards: 60-300 segundos

2. **Tamanho de Arquivo**: Otimize arquivos antes do upload
   - Comprima imagens para reduzir tamanho
   - Use resolução apropriada para o display
   - Converta vídeos para formatos web-friendly

3. **Mix de Conteúdo**: Balance tipos de conteúdo
   - Misture conteúdo estático e dinâmico
   - Evite muitos itens de longa duração
   - Teste temporização de rotação antes de implantar

4. **Organização de Arquivos**: Mantenha mídia organizada
   - Use nomes de arquivo descritivos
   - Remova arquivos não utilizados regularmente
   - Mantenha backup de conteúdo importante

## Gerenciamento de Usuários

### Criar Novos Usuários

Para criar novo usuário admin:

```bash
sudo bash manage.sh user-create
```

Siga os prompts para inserir nome de usuário e senha.

Ou crie via interface admin:
1. Faça login na interface admin
2. Navegue para "Usuários"
3. Clique em "Novo Usuário"
4. Digite nome de usuário e senha
5. Selecione função (admin ou viewer)
6. Clique em "Criar"

### Listar Usuários

Para listar todos os usuários:

```bash
sudo bash manage.sh user-list
```

Ou visualize na interface admin:
1. Faça login na interface admin
2. Navegue para "Usuários"
3. Veja lista de usuários com detalhes

### Alterar Senhas

Via interface admin:
1. Navegue para "Usuários"
2. Encontre usuário para modificar
3. Clique no botão editar
4. Digite nova senha
5. Clique em "Salvar"

### Excluir Usuários

Via interface admin:
1. Navegue para "Usuários"
2. Encontre usuário para excluir
3. Clique no botão excluir
4. Confirme exclusão

Nota: Não é possível excluir o usuário admin padrão.

### Funções de Usuário

- **Admin**: Acesso completo a todos os recursos
  - Gerenciar conteúdo
  - Gerenciar usuários
  - Ver logs
  - Configurar sistema

- **Viewer**: Acesso somente leitura
  - Ver lista de conteúdo
  - Ver status do sistema
  - Não pode modificar nada

## Manutenção do Sistema

### Tarefas de Manutenção Regular

#### Diariamente
- Verificar se display kiosk está funcionando
- Verificar se conteúdo está rotacionando corretamente
- Monitorar mensagens de erro

#### Semanalmente
- Revisar logs do sistema para erros
- Verificar uso de espaço em disco
- Verificar se backups estão executando
- Atualizar conteúdo conforme necessário

#### Mensalmente
- Revisar e limpar arquivos de log antigos
- Remover arquivos de mídia não utilizados
- Atualizar pacotes do sistema
- Testar restauração de backup
- Revisar acesso de usuários

### Atualizar Pacotes do Sistema

Mantenha Ubuntu e pacotes atualizados:

```bash
sudo apt update
sudo apt upgrade -y
```

Reinicie após atualizações importantes:

```bash
sudo reboot
```

### Atualizar Aplicação CrediVision

Para atualizar a aplicação:

```bash
sudo bash manage.sh update
```

Isso irá:
1. Baixar código mais recente do repositório
2. Parar serviços
3. Reconstruir imagem Docker
4. Reiniciar serviços

### Limpeza

Remover imagens Docker antigas:

```bash
docker image prune -a
```

Remover arquivos de log antigos:

```bash
sudo journalctl --vacuum-time=30d
```

Limpar arquivos de mídia não utilizados:

```bash
# Listar arquivos no diretório de mídia
ls -lh ~/Documents/kiosk-media/images/
ls -lh ~/Documents/kiosk-media/videos/

# Remover arquivos específicos não utilizados
rm ~/Documents/kiosk-media/images/arquivo_antigo.jpg
```

### Gerenciamento de Espaço em Disco

Verificar uso de disco:

```bash
df -h
```

Verificar tamanho de diretórios:

```bash
du -sh ~/Documents/kiosk-data
du -sh ~/Documents/kiosk-media
du -sh ~/Documents/kiosk-backups
```

Se espaço em disco estiver baixo:
1. Remover backups antigos
2. Excluir arquivos de mídia não utilizados
3. Limpar imagens Docker
4. Revisar e arquivar logs antigos

## Backup e Restauração

### Backups Automáticos

Backups automáticos executam diariamente à meia-noite.

Backup inclui:
- Todos os arquivos de dados JSON (tabs, users, logs)
- Todos os arquivos de mídia (imagens, vídeos)

Backups são armazenados em: ~/Documents/kiosk-backups/

Retenção: Últimos 7 dias (backups mais antigos auto-excluídos)

### Backup Manual

Para criar backup manual:

```bash
sudo bash manage.sh backup
```

Arquivo de backup criado: ~/Documents/kiosk-backups/manual_backup_TIMESTAMP.tar.gz

### Restaurar de Backup

Para restaurar de um backup:

```bash
sudo bash manage.sh restore
```

Siga os prompts para:
1. Ver backups disponíveis
2. Selecionar arquivo de backup para restaurar
3. Confirmar restauração

Processo:
1. Estado atual é automaticamente copiado
2. Serviços são parados
3. Backup é extraído
4. Permissões são corrigidas
5. Serviços são reiniciados

### Boas Práticas de Backup

1. Teste restauração periodicamente
2. Armazene backups críticos fora do local
3. Verifique integridade do backup
4. Documente cronograma de backup
5. Mantenha múltiplas cópias de backup

## Monitoramento

### Verificações de Saúde do Sistema

Executar diagnóstico:

```bash
sudo bash manage.sh diagnose
```

Verifica:
- Informações do sistema
- Status dos serviços
- Status do Docker
- Status do container
- Status de diretórios
- Status de arquivos
- Status de rede
- Status da API
- Status do Firefox
- Erros recentes

### Monitorar Serviços

Verificar status dos serviços:

```bash
sudo systemctl status credivision-app.service
sudo systemctl status credivision-kiosk.service
sudo systemctl status credivision-backup.timer
```

### Monitorar Docker

Verificar status do container:

```bash
docker ps
```

Verificar logs do container:

```bash
docker logs credivision-app
docker logs -f credivision-app  # Seguir logs
```

Verificar uso de recursos do container:

```bash
docker stats credivision-app
```

### Monitorar Rede

Verificar status da porta:

```bash
sudo netstat -tlnp | grep 5000
```

Testar API localmente:

```bash
curl http://localhost:5000/api/config
```

Testar API remotamente:

```bash
curl http://IP_DO_SERVIDOR:5000/api/config
```

### Monitorar Logs

Ver logs da aplicação:

```bash
sudo journalctl -u credivision-app.service -f
```

Ver logs do kiosk:

```bash
sudo journalctl -u credivision-kiosk.service -f
```

Ver todos os logs do CrediVision:

```bash
sudo journalctl -u credivision-* -f
```

Filtrar logs por prioridade:

```bash
# Apenas erros
sudo journalctl -u credivision-app.service -p err

# Avisos e erros
sudo journalctl -u credivision-app.service -p warning
```

Ver logs para período específico:

```bash
# Última hora
sudo journalctl -u credivision-app.service --since "1 hour ago"

# Data específica
sudo journalctl -u credivision-app.service --since "2024-01-15"
```

## Solução de Problemas

### Problemas Comuns

#### Kiosk Não Está Exibindo

Sintomas: Firefox não está mostrando ou mostrando tela em branco

Soluções:
1. Verificar status do serviço kiosk:
   ```bash
   sudo systemctl status credivision-kiosk.service
   ```

2. Reiniciar serviço kiosk:
   ```bash
   sudo systemctl restart credivision-kiosk.service
   ```

3. Verificar variável DISPLAY:
   ```bash
   echo $DISPLAY
   ```

4. Testar Firefox manualmente:
   ```bash
   DISPLAY=:0 firefox --kiosk http://localhost:5000/display
   ```

5. Verificar servidor X:
   ```bash
   ps aux | grep Xorg
   ```

#### Conteúdo Não Está Rotacionando

Sintomas: Display travado em uma aba

Soluções:
1. Verificar abas configuradas:
   ```bash
   cat ~/Documents/kiosk-data/tabs.json
   ```

2. Verificar se abas estão ativas na interface admin

3. Verificar console JavaScript no Firefox (F12)

4. Reiniciar kiosk:
   ```bash
   sudo systemctl restart credivision-kiosk.service
   ```

#### Não Consegue Acessar Interface Admin

Sintomas: Não consegue conectar a http://IP_DO_SERVIDOR:5000

Soluções:
1. Verificar serviço da aplicação:
   ```bash
   sudo systemctl status credivision-app.service
   ```

2. Verificar container Docker:
   ```bash
   docker ps | grep credivision-app
   ```

3. Verificar se porta está escutando:
   ```bash
   sudo netstat -tlnp | grep 5000
   ```

4. Testar localmente:
   ```bash
   curl http://localhost:5000
   ```

5. Verificar firewall:
   ```bash
   sudo ufw status
   ```

6. Reiniciar aplicação:
   ```bash
   sudo systemctl restart credivision-app.service
   ```

#### Upload Falha

Sintomas: Upload de arquivo retorna erro

Soluções:
1. Verificar tamanho do arquivo (máx 100MB)

2. Verificar formato do arquivo (apenas tipos suportados)

3. Verificar espaço em disco:
   ```bash
   df -h ~/Documents
   ```

4. Verificar permissões de diretório:
   ```bash
   ls -la ~/Documents/kiosk-media/
   ```

5. Corrigir permissões se necessário:
   ```bash
   sudo chown -R $USER:$USER ~/Documents/kiosk-media
   chmod 755 ~/Documents/kiosk-media
   ```

#### Serviço Não Inicia

Sintomas: systemctl start falha

Soluções:
1. Verificar logs do serviço:
   ```bash
   sudo journalctl -u credivision-app.service -n 50
   ```

2. Verificar se Docker está em execução:
   ```bash
   sudo systemctl status docker
   ```

3. Verificar conflitos de porta:
   ```bash
   sudo netstat -tlnp | grep 5000
   ```

4. Verificar se arquivos de configuração existem:
   ```bash
   ls -la docker-compose.yml .env
   ```

5. Tentar iniciar Docker manualmente:
   ```bash
   cd /caminho/para/credivision
   docker compose up -d
   ```

### Obter Ajuda

Se problemas persistirem:

1. Executar diagnóstico:
   ```bash
   sudo bash manage.sh diagnose
   ```

2. Coletar logs:
   ```bash
   sudo journalctl -u credivision-* > credivision-logs.txt
   docker logs credivision-app > docker-logs.txt
   ```

3. Verificar documentação:
   - INSTALACAO.md para problemas de instalação
   - OPERACAO.md (este arquivo) para problemas operacionais
   - LEIAME.md para visão geral do sistema

4. Revisar issues no GitHub para problemas similares

## Configuração Avançada

### Alterar Porta

Para alterar a porta padrão (5000):

1. Editar docker-compose.yml:
   ```bash
   nano docker-compose.yml
   ```

2. Alterar seção ports:
   ```yaml
   ports:
     - "NOVA_PORTA:5000"
   ```

3. Editar serviço kiosk:
   ```bash
   sudo nano /etc/systemd/system/credivision-kiosk.service
   ```

4. Atualizar linha ExecStart:
   ```
   ExecStart=/usr/bin/firefox --kiosk http://localhost:NOVA_PORTA/display ...
   ```

5. Recarregar e reiniciar:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart credivision-app.service
   sudo systemctl restart credivision-kiosk.service
   ```

### Ajustar Delay do Kiosk

Para alterar o delay de 30 segundos antes do kiosk iniciar:

1. Editar serviço kiosk:
   ```bash
   sudo nano /etc/systemd/system/credivision-kiosk.service
   ```

2. Alterar linha ExecStartPre:
   ```
   ExecStartPre=/bin/sleep NOVO_DELAY
   ```

3. Recarregar e reiniciar:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart credivision-kiosk.service
   ```

### Configurar Auto-Login

Para kiosk iniciar automaticamente sem login manual:

1. Editar configuração GDM:
   ```bash
   sudo nano /etc/gdm3/custom.conf
   ```

2. Adicionar sob [daemon]:
   ```ini
   AutomaticLoginEnable=true
   AutomaticLogin=SEU_USUARIO
   ```

3. Reiniciar GDM:
   ```bash
   sudo systemctl restart gdm3
   ```

### Personalizar Cronograma de Backup

Para alterar frequência de backup:

1. Editar timer de backup:
   ```bash
   sudo nano /etc/systemd/system/credivision-backup.timer
   ```

2. Alterar valor OnCalendar:
   ```ini
   OnCalendar=daily          # Diariamente à meia-noite
   OnCalendar=weekly         # Semanalmente
   OnCalendar=*-*-* 02:00:00 # Diariamente às 2h
   ```

3. Recarregar timer:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart credivision-backup.timer
   ```

## Melhores Práticas

### Segurança

1. Alterar senha padrão do admin imediatamente
2. Usar senhas fortes e únicas
3. Limitar acesso de usuários ao pessoal necessário
4. Manter sistema e pacotes atualizados
5. Monitorar logs para atividade suspeita
6. Usar firewall para restringir acesso
7. Auditorias de segurança regulares

### Performance

1. Otimizar arquivos de mídia antes do upload
2. Usar durações apropriadas para conteúdo
3. Monitorar recursos do sistema regularmente
4. Limpar arquivos não utilizados periodicamente
5. Manter imagens Docker atualizadas
6. Reiniciar serviços semanalmente

### Confiabilidade

1. Testar auto-inicialização após atualizações do sistema
2. Verificar backups regularmente
3. Monitorar espaço em disco
4. Manter hardware sobressalente disponível
5. Documentar configurações personalizadas
6. Treinar operadores de backup

### Gerenciamento de Conteúdo

1. Planejar cronograma de rotação de conteúdo
2. Testar novo conteúdo antes de implantar
3. Manter conteúdo fresco e relevante
4. Remover conteúdo desatualizado prontamente
5. Manter biblioteca de conteúdo
6. Documentar fontes de conteúdo

## Recursos de Suporte

- Guia de Instalação: INSTALACAO.md
- Visão Geral do Sistema: LEIAME.md
- Script de Gerenciamento: manage.sh
- Repositório do Projeto: GitHub
- Logs do Sistema: /var/log/syslog
- Logs da Aplicação: journalctl -u credivision-*
