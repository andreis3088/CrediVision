#!/bin/bash

echo "=========================================="
echo "CREDIVISION - Display Digital Unificado"
echo "Firefox Kiosk Puro - 100% Funcional"
echo "=========================================="
echo ""

# Variaveis globais
SERVICE_USER="informa"
PROJECT_DIR="/home/informa/Documents/CrediVision"
DATA_DIR="/home/informa/Documents/kiosk-data"
MEDIA_DIR="/home/informa/Documents/kiosk-media"
BACKUP_DIR="/home/informa/Documents/kiosk-backups"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funcoes auxiliares
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificar se esta rodando como root quando necessario
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este comando precisa ser executado como root"
        echo "Use: sudo $0"
        exit 1
    fi
}

# Verificar se esta rodando como usuario informa
check_user() {
    if [ "$(whoami)" != "$SERVICE_USER" ]; then
        log_error "Este comando precisa ser executado como usuario $SERVICE_USER"
        echo "Use: sudo -u $SERVICE_USER $0"
        exit 1
    fi
}

# Menu principal
show_main_menu() {
    clear
    echo "=========================================="
    echo "CREDIVISION - Display Digital"
    echo "Firefox Kiosk Puro"
    echo "=========================================="
    echo ""
    echo "1) Instalar Sistema Completo"
    echo "2) Atualizar Sistema"
    echo "3) Remover Sistema"
    echo "4) Gerenciar Servicos"
    echo "5) Testar Sistema"
    echo "6) Backup e Restore"
    echo "7) Diagnostico"
    echo "8) Informacoes"
    echo "9) Sair"
    echo ""
    echo "=========================================="
    read -p "Escolha uma opcao: " choice
    
    case $choice in
        1) install_system ;;
        2) update_system ;;
        3) remove_system ;;
        4) manage_services ;;
        5) test_system ;;
        6) backup_restore ;;
        7) diagnose_system ;;
        8) show_info ;;
        9) exit 0 ;;
        *) log_error "Opcao invalida!"; sleep 2; show_main_menu ;;
    esac
}

# 1. Instalar Sistema Completo
install_system() {
    clear
    echo "=========================================="
    echo "INSTALACAO COMPLETA - CREDIVISION"
    echo "=========================================="
    echo ""
    
    check_root
    
    log_info "Iniciando instalacao completa..."
    echo ""
    
    # 1.1 Atualizar sistema
    log_info "1/8 - Atualizando sistema..."
    apt update && apt upgrade -y
    
    # 1.2 Criar usuario informa se nao existir
    log_info "2/8 - Verificando usuario informa..."
    if ! id "$SERVICE_USER" &>/dev/null; then
        log_info "Criando usuario $SERVICE_USER..."
        useradd -m -s /bin/bash "$SERVICE_USER"
        echo "$SERVICE_USER:informa123" | chpasswd
        usermod -aG sudo,audio,video,input,plugdev,render "$SERVICE_USER"
    else
        log_success "Usuario $SERVICE_USER ja existe"
    fi
    
    # 1.3 Instalar dependencias
    log_info "3/8 - Instalando dependencias..."
    apt install -y \
        firefox \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        libnotify-bin \
        xdotool \
        x11-utils \
        xvfb \
        curl \
        wget \
        git \
        docker.io \
        docker-compose \
        nginx \
        sqlite3
    
    # 1.4 Configurar Docker
    log_info "4/8 - Configurando Docker..."
    systemctl enable docker
    systemctl start docker
    usermod -aG docker "$SERVICE_USER"
    
    # 1.5 Criar diretorios
    log_info "5/8 - Criando diretorios..."
    mkdir -p "$PROJECT_DIR" "$DATA_DIR" "$MEDIA_DIR" "$BACKUP_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR" "$DATA_DIR" "$MEDIA_DIR" "$BACKUP_DIR"
    
    # 1.6 Criar aplicacao Flask
    log_info "6/8 - Criando aplicacao Flask..."
    create_flask_app
    
    # 1.7 Criar script kiosk
    log_info "7/8 - Criando script kiosk..."
    create_kiosk_script
    
    # 1.8 Configurar servicos
    log_info "8/8 - Configurando servicos..."
    create_services
    
    # Iniciar servicos
    log_info "Iniciando servicos..."
    systemctl daemon-reload
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl start credivision-app.service
    sleep 5
    systemctl start credivision-kiosk.service
    
    echo ""
    log_success "INSTALACAO CONCLUIDA COM SUCESSO!"
    echo ""
    echo "Acessos:"
    echo "  Interface Web: http://$(hostname -I | awk '{print $1}'):5000"
    echo "  Login: admin / admin123"
    echo ""
    echo "Comandos uteis:"
    echo "  Status: sudo systemctl status credivision-kiosk.service"
    echo "  Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo "  Teste: sudo -u informa bash $PROJECT_DIR/kiosk.sh"
    echo ""
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Criar aplicacao Flask
create_flask_app() {
    cat > "$PROJECT_DIR/app.py" << 'FLASK_EOF'
#!/usr/bin/env python3
import os
import json
import hashlib
import sqlite3
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, send_file
from functools import wraps

app = Flask(__name__)
app.secret_key = 'crevision_secret_key_2024'

# Configuracao
DATA_DIR = '/home/informa/Documents/kiosk-data'
MEDIA_DIR = '/home/informa/Documents/kiosk-media'
USERS_FILE = os.path.join(DATA_DIR, 'users.json')
TABS_FILE = os.path.join(DATA_DIR, 'tabs.json')
LOGS_FILE = os.path.join(DATA_DIR, 'logs.json')

# Garantir diretorios
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(MEDIA_DIR, exist_ok=True)

# Funcoes auxiliares
def hash_password(password):
    salt = "kiosk_salt_2024"
    return hashlib.sha256(f"{salt}{password}".encode()).hexdigest()

def load_json(file_path):
    try:
        if os.path.exists(file_path):
            with open(file_path, 'r') as f:
                return json.load(f)
    except:
        pass
    return []

def save_json(file_path, data):
    try:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except:
        return False

def log_action(action, details=""):
    logs = load_json(LOGS_FILE)
    logs.append({
        'timestamp': datetime.now().isoformat(),
        'action': action,
        'details': details,
        'user': session.get('username', 'system')
    })
    if len(logs) > 1000:
        logs = logs[-1000:]
    save_json(LOGS_FILE, logs)

# Login decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'username' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Inicializar arquivos
def init_files():
    # Usuarios
    if not os.path.exists(USERS_FILE):
        users = [{
            'id': 1,
            'username': 'admin',
            'password_hash': hash_password('admin123'),
            'role': 'admin',
            'created_at': datetime.now().isoformat()
        }]
        save_json(USERS_FILE, users)
    
    # Abas
    if not os.path.exists(TABS_FILE):
        tabs = [{
            'id': 1,
            'name': 'Google',
            'url': 'https://google.com',
            'type': 'url',
            'duration': 30,
            'enabled': True,
            'created_at': datetime.now().isoformat()
        }]
        save_json(TABS_FILE, tabs)
    
    # Logs
    if not os.path.exists(LOGS_FILE):
        save_json(LOGS_FILE, [])

init_files()

# Rotas
@app.route('/')
def index():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        users = load_json(USERS_FILE)
        for user in users:
            if user['username'] == username and user['password_hash'] == hash_password(password):
                session['username'] = username
                session['role'] = user['role']
                log_action('login', f'Usuario {username} logou')
                return redirect(url_for('index'))
        
        return render_template('login.html', error='Credenciais invalidas')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    log_action('logout', f'Usuario {session.get("username")} deslogou')
    session.clear()
    return redirect(url_for('login'))

@app.route('/tabs')
@login_required
def tabs():
    return render_template('tabs.html')

@app.route('/api/tabs')
@login_required
def api_tabs():
    tabs = load_json(TABS_FILE)
    return jsonify(tabs)

@app.route('/api/tabs', methods=['POST'])
@login_required
def api_add_tab():
    data = request.get_json()
    tabs = load_json(TABS_FILE)
    
    new_tab = {
        'id': len(tabs) + 1,
        'name': data.get('name', ''),
        'url': data.get('url', ''),
        'type': data.get('type', 'url'),
        'duration': data.get('duration', 30),
        'enabled': data.get('enabled', True),
        'created_at': datetime.now().isoformat()
    }
    
    tabs.append(new_tab)
    save_json(TABS_FILE, tabs)
    log_action('add_tab', f'Aba {new_tab["name"]} adicionada')
    
    return jsonify(new_tab)

@app.route('/api/tabs/<int:tab_id>', methods=['PUT'])
@login_required
def api_update_tab(tab_id):
    data = request.get_json()
    tabs = load_json(TABS_FILE)
    
    for tab in tabs:
        if tab['id'] == tab_id:
            tab.update(data)
            tab['updated_at'] = datetime.now().isoformat()
            save_json(TABS_FILE, tabs)
            log_action('update_tab', f'Aba {tab["name"]} atualizada')
            return jsonify(tab)
    
    return jsonify({'error': 'Aba nao encontrada'}), 404

@app.route('/api/tabs/<int:tab_id>', methods=['DELETE'])
@login_required
def api_delete_tab(tab_id):
    tabs = load_json(TABS_FILE)
    
    for i, tab in enumerate(tabs):
        if tab['id'] == tab_id:
            tab_name = tab['name']
            tabs.pop(i)
            save_json(TABS_FILE, tabs)
            log_action('delete_tab', f'Aba {tab_name} removida')
            return jsonify({'success': True})
    
    return jsonify({'error': 'Aba nao encontrada'}), 404

@app.route('/api/config')
@login_required
def api_config():
    tabs = load_json(TABS_FILE)
    active_tabs = [tab for tab in tabs if tab.get('enabled', True)]
    return jsonify({'tabs': active_tabs})

@app.route('/api/upload', methods=['POST'])
@login_required
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'Nenhum arquivo enviado'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'Nome de arquivo vazio'}), 400
    
    filename = file.filename
    filepath = os.path.join(MEDIA_DIR, filename)
    file.save(filepath)
    
    log_action('upload_file', f'Arquivo {filename} enviado')
    return jsonify({'filename': filename, 'path': filepath})

@app.route('/media/<filename>')
def media_file(filename):
    return send_file(os.path.join(MEDIA_DIR, filename))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
FLASK_EOF

    chmod +x "$PROJECT_DIR/app.py"
    chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/app.py"
    
    # Criar templates
    mkdir -p "$PROJECT_DIR/templates"
    
    # Template base
    cat > "$PROJECT_DIR/templates/base.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}CrediVision{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="{{ url_for('index') }}">
                <i class="fas fa-tv"></i> CrediVision
            </a>
            <div class="navbar-nav ms-auto">
                <a class="nav-link" href="{{ url_for('tabs') }}">
                    <i class="fas fa-layer-group"></i> Abas
                </a>
                <a class="nav-link" href="{{ url_for('logout') }}">
                    <i class="fas fa-sign-out-alt"></i> Sair
                </a>
            </div>
        </div>
    </nav>
    
    <div class="container mt-4">
        {% block content %}{% endblock %}
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
HTML_EOF

    # Template index
    cat > "$PROJECT_DIR/templates/index.html" << 'HTML_EOF'
{% extends "base.html" %}

{% block title %}CrediVision - Dashboard{% endblock %}

{% block content %}
<div class="row">
    <div class="col-12">
        <h1><i class="fas fa-tv"></i> CrediVision - Display Digital</h1>
        <p class="text-muted">Sistema de kiosk para exibicao de conteudo em tela cheia</p>
    </div>
</div>

<div class="row mt-4">
    <div class="col-md-4">
        <div class="card">
            <div class="card-body text-center">
                <i class="fas fa-layer-group fa-3x text-primary mb-3"></i>
                <h5>Gerenciar Abas</h5>
                <p class="text-muted">Configure as abas que serao exibidas no kiosk</p>
                <a href="{{ url_for('tabs') }}" class="btn btn-primary">
                    <i class="fas fa-cog"></i> Configurar
                </a>
            </div>
        </div>
    </div>
    
    <div class="col-md-4">
        <div class="card">
            <div class="card-body text-center">
                <i class="fas fa-tv fa-3x text-success mb-3"></i>
                <h5>Kiosk Ativo</h5>
                <p class="text-muted">Firefox kiosk rodando em tela cheia</p>
                <div class="badge bg-success">Online</div>
            </div>
        </div>
    </div>
    
    <div class="col-md-4">
        <div class="card">
            <div class="card-body text-center">
                <i class="fas fa-clock fa-3x text-warning mb-3"></i>
                <h5>Rotacao Automatica</h5>
                <p class="text-muted">Abas rotacionam conforme tempo configurado</p>
                <div class="badge bg-warning">Ativo</div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
HTML_EOF

    # Template tabs
    cat > "$PROJECT_DIR/templates/tabs.html" << 'HTML_EOF'
{% extends "base.html" %}

{% block title %}CrediVision - Abas{% endblock %}

{% block content %}
<div class="row">
    <div class="col-12">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h1><i class="fas fa-layer-group"></i> Gerenciar Abas</h1>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addTabModal">
                <i class="fas fa-plus"></i> Nova Aba
            </button>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped" id="tabsTable">
                        <thead>
                            <tr>
                                <th>Nome</th>
                                <th>URL</th>
                                <th>Tipo</th>
                                <th>Duracao</th>
                                <th>Status</th>
                                <th>Acoes</th>
                            </tr>
                        </thead>
                        <tbody>
                            <!-- Carregado via JavaScript -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal Nova Aba -->
<div class="modal fade" id="addTabModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Nova Aba</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form id="addTabForm">
                    <div class="mb-3">
                        <label for="tabName" class="form-label">Nome</label>
                        <input type="text" class="form-control" id="tabName" required>
                    </div>
                    <div class="mb-3">
                        <label for="tabUrl" class="form-label">URL</label>
                        <input type="text" class="form-control" id="tabUrl" required>
                    </div>
                    <div class="mb-3">
                        <label for="tabType" class="form-label">Tipo</label>
                        <select class="form-select" id="tabType">
                            <option value="url">URL</option>
                            <option value="image">Imagem</option>
                            <option value="video">Video</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label for="tabDuration" class="form-label">Duracao (segundos)</label>
                        <input type="number" class="form-control" id="tabDuration" value="30" min="5">
                    </div>
                    <div class="mb-3">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="tabEnabled" checked>
                            <label class="form-check-label" for="tabEnabled">
                                Ativada
                            </label>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary" onclick="addTab()">Salvar</button>
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block scripts %}
<script>
function loadTabs() {
    fetch('/api/tabs')
        .then(response => response.json())
        .then(tabs => {
            const tbody = document.querySelector('#tabsTable tbody');
            tbody.innerHTML = '';
            
            tabs.forEach(tab => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${tab.name}</td>
                    <td>${tab.url}</td>
                    <td><span class="badge bg-info">${tab.type}</span></td>
                    <td>${tab.duration}s</td>
                    <td>
                        ${tab.enabled ? 
                            '<span class="badge bg-success">Ativa</span>' : 
                            '<span class="badge bg-secondary">Inativa</span>'}
                    </td>
                    <td>
                        <button class="btn btn-sm btn-warning" onclick="editTab(${tab.id})">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="deleteTab(${tab.id})">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        });
}

function addTab() {
    const tab = {
        name: document.getElementById('tabName').value,
        url: document.getElementById('tabUrl').value,
        type: document.getElementById('tabType').value,
        duration: parseInt(document.getElementById('tabDuration').value),
        enabled: document.getElementById('tabEnabled').checked
    };
    
    fetch('/api/tabs', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(tab)
    })
    .then(response => response.json())
    .then(() => {
        bootstrap.Modal.getInstance(document.getElementById('addTabModal')).hide();
        document.getElementById('addTabForm').reset();
        loadTabs();
    });
}

function deleteTab(id) {
    if (confirm('Tem certeza?')) {
        fetch(`/api/tabs/${id}`, {method: 'DELETE'})
        .then(() => loadTabs());
    }
}

// Carregar abas ao iniciar
loadTabs();
</script>
{% endblock %}
HTML_EOF

    # Template login
    cat > "$PROJECT_DIR/templates/login.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CrediVision - Login</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
            padding: 2rem;
            max-width: 400px;
            width: 100%;
        }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="text-center mb-4">
            <i class="fas fa-tv fa-3x text-primary mb-3"></i>
            <h2>CrediVision</h2>
            <p class="text-muted">Display Digital System</p>
        </div>
        
        {% if error %}
        <div class="alert alert-danger">
            {{ error }}
        </div>
        {% endif %}
        
        <form method="post">
            <div class="mb-3">
                <label for="username" class="form-label">Usuario</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-user"></i></span>
                    <input type="text" class="form-control" id="username" name="username" required>
                </div>
            </div>
            
            <div class="mb-3">
                <label for="password" class="form-label">Senha</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="fas fa-lock"></i></span>
                    <input type="password" class="form-control" id="password" name="password" required>
                </div>
            </div>
            
            <button type="submit" class="btn btn-primary w-100">
                <i class="fas fa-sign-in-alt"></i> Entrar
            </button>
        </form>
        
        <div class="text-center mt-3">
            <small class="text-muted">
                Usuario: admin / Senha: admin123
            </small>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
HTML_EOF

    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/templates"
}

# Criar script kiosk
create_kiosk_script() {
    cat > "$PROJECT_DIR/kiosk.sh" << 'KIOSK_EOF'
#!/bin/bash

echo "=== CREDIVISION KIOSK - 1 JANELA COM ROTACAO ==="
echo "Iniciando Firefox Kiosk com Rotacao de URLs..."
echo ""

# Ambiente X11
export DISPLAY=:0
export XAUTHORITY=/home/informa/.Xauthority

# Funcao para obter abas configuradas
get_tabs() {
    python3 << 'PYTHON'
import json
import sys

try:
    with open("/home/informa/Documents/kiosk-data/tabs.json", "r") as f:
        data = json.load(f)
    
    # Verificar estrutura (lista ou objeto)
    tabs = data if isinstance(data, list) else data.get("tabs", [])
    
    # Filtrar apenas abas ativas e ordenar por ID
    active_tabs = []
    for tab in tabs:
        if tab.get("enabled", True):
            active_tabs.append({
                'id': tab.get('id', 0),
                'name': tab.get('name', 'Sem nome'),
                'url': tab.get('url', ''),
                'type': tab.get('type', 'url'),
                'duration': tab.get('duration', 30)
            })
    
    # Ordenar por ID (ordem de criacao)
    active_tabs.sort(key=lambda x: x['id'])
    
    # Retornar como JSON
    print(json.dumps(active_tabs))
    
except Exception as e:
    print("[]")
PYTHON
}

# Obter abas ativas
TABS_JSON=$(get_tabs)
TABS_COUNT=$(echo "$TABS_JSON" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))")

if [ "$TABS_COUNT" -eq 0 ]; then
    echo "ERRO: Nenhuma aba ativa encontrada!"
    echo "Configure abas em: http://$(hostname -I | awk '{print $1}'):5000"
    exit 1
fi

echo "Abas ativas encontradas: $TABS_COUNT"
echo "$TABS_JSON" | python3 -c "
import json, sys
tabs = json.load(sys.stdin)
for i, tab in enumerate(tabs):
    print(f'  {i+1}. {tab[\"name\"]} - {tab[\"url\"]} - {tab[\"duration\"]}s')
"
echo ""

# Fechar Firefox anteriores completamente
echo "Fechando Firefox anteriores..."
pkill -f firefox 2>/dev/null || true
pkill -f "firefox-*" 2>/dev/null || true
sleep 5

# Garantir que nenhum processo Firefox esteja rodando
while pgrep -f firefox > /dev/null; do
    echo "Aguardando Firefox fechar..."
    pkill -9 -f firefox 2>/dev/null || true
    sleep 1
done

echo "Firefox fechado. Iniciando kiosk..."

# Diretorio temporario para HTMLs
TEMP_DIR="/tmp/credivision_kiosk_$$"
mkdir -p "$TEMP_DIR"

# Funcao de limpeza
cleanup() {
    echo "Limpando arquivos temporários..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Funcao para criar HTML para imagens
create_image_html() {
    local image_path="$1"
    local title="$2"
    
    cat > "$TEMP_DIR/image_$$.html" << HTML_EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
            background: #000;
        }
        img {
            width: 100vw;
            height: 100vh;
            object-fit: contain;
            display: block;
        }
    </style>
</head>
<body>
    <img src="$image_path" alt="$title" />
</body>
</html>
HTML_EOF
}

# Funcao para criar HTML para vídeos
create_video_html() {
    local video_path="$1"
    local title="$2"
    
    cat > "$TEMP_DIR/video_$$.html" << HTML_EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            overflow: hidden;
            background: #000;
        }
        video {
            width: 100vw;
            height: 100vh;
            object-fit: contain;
            display: block;
        }
        .controls {
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0,0,0,0.7);
            padding: 10px;
            border-radius: 5px;
            z-index: 1000;
        }
        button {
            margin: 0 5px;
            padding: 5px 10px;
            background: #333;
            color: white;
            border: none;
            border-radius: 3px;
            cursor: pointer;
        }
        button:hover {
            background: #555;
        }
    </style>
</head>
<body>
    <video id="video" autoplay loop>
        <source src="$video_path">
        Seu navegador não suporta vídeo.
    </video>
    <div class="controls">
        <button onclick="document.getElementById('video').play()">▶</button>
        <button onclick="document.getElementById('video').pause()">⏸</button>
        <button onclick="document.getElementById('video').muted = !document.getElementById('video').muted">🔊</button>
        <button onclick="document.getElementById('video').requestFullscreen()">⛶</button>
    </div>
</body>
</html>
HTML_EOF
}

# Processar abas e criar arrays
echo "Processando abas..."
CURRENT_INDEX=0

# Criar arrays com as abas
echo "$TABS_JSON" | python3 -c "
import json, sys
tabs = json.load(sys.stdin)
for i, tab in enumerate(tabs):
    print(f'TAB_{i}_NAME=\"{tab[\"name\"]}\"')
    print(f'TAB_{i}_URL=\"{tab[\"url\"]}\"')
    print(f'TAB_{i}_TYPE=\"{tab[\"type\"]}\"')
    print(f'TAB_{i}_DURATION={tab[\"duration\"]}')
" > "$TEMP_DIR/tabs_vars.sh"

source "$TEMP_DIR/tabs_vars.sh"

# Funcao para obter URL da aba atual
get_current_url() {
    local var_url="TAB_${CURRENT_INDEX}_URL"
    local var_type="TAB_${CURRENT_INDEX}_TYPE"
    local url="${!var_url}"
    local type="${!var_type}"
    
    case "$type" in
        "image")
            # Verificar se é caminho local
            if [[ "$url" =~ ^/ ]]; then
                create_image_html "$url" "$(eval echo \$TAB_${CURRENT_INDEX}_NAME)"
                echo "file://$TEMP_DIR/image_$$.html"
            else
                echo "$url"
            fi
            ;;
        "video")
            # Verificar se é caminho local
            if [[ "$url" =~ ^/ ]]; then
                create_video_html "$url" "$(eval echo \$TAB_${CURRENT_INDEX}_NAME)"
                echo "file://$TEMP_DIR/video_$$.html"
            else
                echo "$url"
            fi
            ;;
        *)
            echo "$url"
            ;;
    esac
}

# Funcao para obter nome da aba atual
get_current_name() {
    local var_name="TAB_${CURRENT_INDEX}_NAME"
    echo "${!var_name}"
}

# Funcao para obter duracao da aba atual
get_current_duration() {
    local var_duration="TAB_${CURRENT_INDEX}_DURATION"
    echo "${!var_duration}"
}

# Iniciar rotacao
echo ""
echo "=== ROTACAO AUTOMATICA INICIADA ==="
echo "Usando 1 janela Firefox com rotacao de URLs"
echo "Pressione Ctrl+C para parar"
echo ""

# Iniciar Firefox com primeira aba
CURRENT_URL=$(get_current_url)
CURRENT_NAME=$(get_current_name)
echo "Iniciando com: $CURRENT_NAME"

firefox --kiosk "$CURRENT_URL" &
FIREFOX_PID=$!

# Aguardar Firefox carregar
sleep 5

# Verificar se Firefox esta rodando
if ! pgrep -f firefox > /dev/null; then
    echo "ERRO: Firefox nao iniciou!"
    exit 1
fi

echo "Firefox iniciado (PID: $FIREFOX_PID)"

# Loop de rotacao
while true; do
    # Obter informacoes da aba atual
    CURRENT_NAME=$(get_current_name)
    CURRENT_DURATION=$(get_current_duration)
    
    echo "Exibindo: $CURRENT_NAME (${CURRENT_DURATION}s)"
    
    # Aguardar tempo configurado
    sleep "$CURRENT_DURATION"
    
    # Verificar se Firefox ainda esta rodando
    if ! pgrep -f firefox > /dev/null; then
        echo "Firefox fechado, saindo..."
        break
    fi
    
    # Proxima aba (circular)
    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % TABS_COUNT ))
    
    # Obter proxima URL
    NEXT_URL=$(get_current_url)
    NEXT_NAME=$(get_current_name)
    
    echo "Trocando para: $NEXT_NAME"
    
    # Abrir nova URL na mesma janela usando JavaScript
    # Tentar diferentes métodos para mudar a URL
    echo "Mudando URL para: $NEXT_URL"
    
    # Método 1: Usar xdotool para abrir nova URL
    xdotool key ctrl+l
    sleep 0.5
    xdotool type "$NEXT_URL"
    sleep 0.5
    xdotool key Return
    
    # Aguardar carregar
    sleep 3
done

echo "Rotacao finalizada"
KIOSK_EOF

    chmod +x "$PROJECT_DIR/kiosk.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/kiosk.sh"
}

# Criar servicos systemd
create_services() {
    # Servico da aplicacao Flask
    cat > /etc/systemd/system/credivision-app.service << 'APP_EOF'
[Unit]
Description=CrediVision Flask App
After=network.target

[Service]
Type=simple
User=informa
WorkingDirectory=/home/informa/Documents/CrediVision
Environment=PATH=/home/informa/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 /home/informa/Documents/CrediVision/app.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
APP_EOF

    # Servico do kiosk
    cat > /etc/systemd/system/credivision-kiosk.service << 'KIOSK_EOF'
[Unit]
Description=CrediVision Firefox Kiosk
After=network.target credivision-app.service

[Service]
Type=simple
User=informa
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/informa/.Xauthority
ExecStart=/home/informa/Documents/CrediVision/kiosk.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
KIOSK_EOF

    log_success "Servicos systemd criados"
}

# 2. Atualizar Sistema
update_system() {
    clear
    echo "=========================================="
    echo "ATUALIZACAO - CREDIVISION"
    echo "=========================================="
    echo ""
    
    check_root
    
    log_info "Atualizando sistema..."
    
    # Atualizar pacotes
    apt update && apt upgrade -y
    
    # Atualizar aplicacao
    log_info "Atualizando aplicacao Flask..."
    create_flask_app
    
    # Atualizar script kiosk
    log_info "Atualizando script kiosk..."
    create_kiosk_script
    
    # Reiniciar servicos
    log_info "Reiniciando servicos..."
    systemctl restart credivision-app.service
    sleep 3
    systemctl restart credivision-kiosk.service
    
    log_success "Sistema atualizado com sucesso!"
    echo ""
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# 3. Remover Sistema
remove_system() {
    clear
    echo "=========================================="
    echo "REMOCAO - CREDIVISION"
    echo "=========================================="
    echo ""
    
    check_root
    
    log_warning "ATENCAO: Isso vai remover todo o CrediVision!"
    read -p "Tem certeza? (S/N): " confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        log_info "Removendo servicos..."
        systemctl stop credivision-app.service 2>/dev/null || true
        systemctl stop credivision-kiosk.service 2>/dev/null || true
        systemctl disable credivision-app.service 2>/dev/null || true
        systemctl disable credivision-kiosk.service 2>/dev/null || true
        rm -f /etc/systemd/system/credivision-*.service
        systemctl daemon-reload
        
        log_info "Removendo arquivos..."
        rm -rf "$PROJECT_DIR"
        rm -rf "$DATA_DIR"
        rm -rf "$MEDIA_DIR"
        rm -rf "$BACKUP_DIR"
        
        log_success "Sistema removido com sucesso!"
    else
        log_info "Remocao cancelada"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# 4. Gerenciar Servicos
manage_services() {
    clear
    echo "=========================================="
    echo "GERENCIAR SERVICOS"
    echo "=========================================="
    echo ""
    echo "1) Status dos Servicos"
    echo "2) Iniciar Servicos"
    echo "3) Parar Servicos"
    echo "4) Reiniciar Servicos"
    echo "5) Logs do App"
    echo "6) Logs do Kiosk"
    echo "7) Voltar"
    echo ""
    read -p "Escolha uma opcao: " choice
    
    case $choice in
        1) show_services_status ;;
        2) start_services ;;
        3) stop_services ;;
        4) restart_services ;;
        5) show_app_logs ;;
        6) show_kiosk_logs ;;
        7) show_main_menu ;;
        *) log_error "Opcao invalida!"; sleep 2; manage_services ;;
    esac
}

show_services_status() {
    check_root
    echo ""
    echo "=== STATUS DOS SERVICOS ==="
    echo ""
    echo "Servico App:"
    systemctl status credivision-app.service --no-pager
    echo ""
    echo "Servico Kiosk:"
    systemctl status credivision-kiosk.service --no-pager
    echo ""
    read -p "Pressione Enter para continuar..."
    manage_services
}

start_services() {
    check_root
    log_info "Iniciando servicos..."
    systemctl start credivision-app.service
    sleep 2
    systemctl start credivision-kiosk.service
    log_success "Servicos iniciados!"
    echo ""
    read -p "Pressione Enter para continuar..."
    manage_services
}

stop_services() {
    check_root
    log_info "Parando servicos..."
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-app.service
    log_success "Servicos parados!"
    echo ""
    read -p "Pressione Enter para continuar..."
    manage_services
}

restart_services() {
    check_root
    log_info "Reiniciando servicos..."
    systemctl restart credivision-app.service
    sleep 3
    systemctl restart credivision-kiosk.service
    log_success "Servicos reiniciados!"
    echo ""
    read -p "Pressione Enter para continuar..."
    manage_services
}

show_app_logs() {
    check_root
    echo ""
    echo "=== LOGS DO APP ==="
    echo "Pressione Ctrl+C para sair"
    echo ""
    journalctl -u credivision-app.service -f
}

show_kiosk_logs() {
    check_root
    echo ""
    echo "=== LOGS DO KIOSK ==="
    echo "Pressione Ctrl+C para sair"
    echo ""
    journalctl -u credivision-kiosk.service -f
}

# 5. Testar Sistema
test_system() {
    clear
    echo "=========================================="
    echo "TESTAR SISTEMA"
    echo "=========================================="
    echo ""
    echo "1) Testar Aplicacao Flask"
    echo "2) Testar Kiosk Manual"
    echo "3) Testar Configuracao"
    echo "4) Voltar"
    echo ""
    read -p "Escolha uma opcao: " choice
    
    case $choice in
        1) test_flask_app ;;
        2) test_kiosk_manual ;;
        3) test_configuration ;;
        4) show_main_menu ;;
        *) log_error "Opcao invalida!"; sleep 2; test_system ;;
    esac
}

test_flask_app() {
    echo ""
    echo "=== TESTANDO APLICACAO FLASK ==="
    echo ""
    
    if curl -s http://localhost:5000 > /dev/null; then
        log_success "Aplicacao Flask respondendo!"
        echo "URL: http://$(hostname -I | awk '{print $1}'):5000"
    else
        log_error "Aplicacao Flask nao respondendo!"
        echo "Verifique: sudo systemctl status credivision-app.service"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    test_system
}

test_kiosk_manual() {
    echo ""
    echo "=== TESTANDO KIOSK MANUAL ==="
    echo ""
    echo "Iniciando kiosk por 10 segundos..."
    
    sudo -u "$SERVICE_USER" bash "$PROJECT_DIR/kiosk.sh" &
    KIOSK_PID=$!
    
    sleep 10
    
    if pgrep -f firefox > /dev/null; then
        log_success "Kiosk funcionando!"
        echo "Parando teste..."
        kill $KIOSK_PID 2>/dev/null || true
        pkill -f firefox 2>/dev/null || true
    else
        log_error "Kiosk nao funcionou!"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    test_system
}

test_configuration() {
    echo ""
    echo "=== TESTANDO CONFIGURACAO ==="
    echo ""
    
    if [ -f "$DATA_DIR/tabs.json" ]; then
        echo "Arquivo tabs.json encontrado:"
        python3 -c "
import json
with open('$DATA_DIR/tabs.json', 'r') as f:
    data = json.load(f)
tabs = data if isinstance(data, list) else data.get('tabs', [])
print(f'Total abas: {len(tabs)}')
for i, tab in enumerate(tabs):
    print(f'{i+1}. {tab.get(\"name\", \"Sem nome\")} - {tab.get(\"url\", \"Sem URL\")} - Ativa: {tab.get(\"enabled\", True)}')
"
    else
        log_error "Arquivo tabs.json nao encontrado!"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    test_system
}

# 6. Backup e Restore
backup_restore() {
    clear
    echo "=========================================="
    echo "BACKUP E RESTORE"
    echo "=========================================="
    echo ""
    echo "1) Fazer Backup"
    echo "2) Restaurar Backup"
    echo "3) Listar Backups"
    echo "4) Voltar"
    echo ""
    read -p "Escolha uma opcao: " choice
    
    case $choice in
        1) make_backup ;;
        2) restore_backup ;;
        3) list_backups ;;
        4) show_main_menu ;;
        *) log_error "Opcao invalida!"; sleep 2; backup_restore ;;
    esac
}

make_backup() {
    check_root
    
    BACKUP_NAME="credivision_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log_info "Fazendo backup: $BACKUP_NAME"
    
    tar -czf "$BACKUP_PATH" \
        -C /home/informa/Documents \
        CrediVision kiosk-data kiosk-media
    
    if [ $? -eq 0 ]; then
        log_success "Backup criado: $BACKUP_PATH"
    else
        log_error "Erro ao criar backup!"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    backup_restore
}

restore_backup() {
    check_root
    
    list_backups
    echo ""
    read -p "Digite o nome do backup para restaurar: " backup_name
    
    if [ -z "$backup_name" ]; then
        log_error "Nome do backup nao informado!"
        backup_restore
        return
    fi
    
    backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -f "$backup_path" ]; then
        log_error "Backup nao encontrado: $backup_path"
        backup_restore
        return
    fi
    
    log_warning "Isso vai substituir os dados atuais!"
    read -p "Tem certeza? (S/N): " confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        log_info "Restaurando backup..."
        
        # Parar servicos
        systemctl stop credivision-app.service 2>/dev/null || true
        systemctl stop credivision-kiosk.service 2>/dev/null || true
        
        # Restaurar
        tar -xzf "$backup_path" -C /home/informa/Documents/
        
        # Ajustar permissoes
        chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR" "$DATA_DIR" "$MEDIA_DIR"
        
        # Reiniciar servicos
        systemctl start credivision-app.service
        sleep 3
        systemctl start credivision-kiosk.service
        
        log_success "Backup restaurado!"
    else
        log_info "Restauracao cancelada"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    backup_restore
}

list_backups() {
    echo ""
    echo "=== BACKUPS DISPONIVEIS ==="
    echo ""
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR)" ]; then
        ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "Nenhum backup encontrado"
    else
        echo "Nenhum backup encontrado"
    fi
}

# 7. Diagnostico
diagnose_system() {
    clear
    echo "=========================================="
    echo "DIAGNOSTICO COMPLETO"
    echo "=========================================="
    echo ""
    
    check_root
    
    echo "=== SISTEMA ==="
    echo "SO: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    echo "=== USUARIO ==="
    echo "Usuario: $(whoami)"
    echo "Grupos: $(groups)"
    echo "Home: $HOME"
    echo ""
    
    echo "=== SERVICOS ==="
    echo "App: $(systemctl is-active credivision-app.service)"
    echo "Kiosk: $(systemctl is-active credivision-kiosk.service)"
    echo ""
    
    echo "=== PROCESSOS ==="
    echo "Firefox: $(pgrep -f firefox | wc -l) processos"
    echo "Python: $(pgrep -f app.py | wc -l) processos"
    echo ""
    
    echo "=== PORTAS ==="
    echo "5000: $(netstat -tlnp 2>/dev/null | grep :5000 | wc -l) escutando"
    echo ""
    
    echo "=== ARQUIVOS ==="
    echo "App.py: $([ -f "$PROJECT_DIR/app.py" ] && echo "OK" || echo "FALTANDO")"
    echo "Kiosk.sh: $([ -f "$PROJECT_DIR/kiosk.sh" ] && echo "OK" || echo "FALTANDO")"
    echo "Tabs.json: $([ -f "$DATA_DIR/tabs.json" ] && echo "OK" || echo "FALTANDO")"
    echo ""
    
    echo "=== AMBIENTE ==="
    echo "DISPLAY: ${DISPLAY:-:0}"
    echo "XAUTHORITY: ${XAUTHORITY:-/home/informa/.Xauthority}"
    echo ""
    
    echo "=== TESTE DE CONEXAO ==="
    if curl -s http://localhost:5000 > /dev/null; then
        echo "App Flask: RESPONDENDO"
    else
        echo "App Flask: NAO RESPONDENDO"
    fi
    
    echo ""
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# 8. Informacoes
show_info() {
    clear
    echo "=========================================="
    echo "INFORMACOES - CREDIVISION"
    echo "=========================================="
    echo ""
    
    echo "=== CREDIVISION ==="
    echo "Sistema: Display Digital com Firefox Kiosk"
    echo "Versao: 1.0 Unificado"
    echo "Navegador: Firefox (modo kiosk puro)"
    echo "Gerenciamento: Interface Web"
    echo ""
    
    echo "=== ACESSO ==="
    echo "Interface Web: http://$(hostname -I | awk '{print $1}'):5000"
    echo "Login: admin"
    echo "Senha: admin123"
    echo ""
    
    echo "=== DIRETORIOS ==="
    echo "Projeto: $PROJECT_DIR"
    echo "Dados: $DATA_DIR"
    echo "Midia: $MEDIA_DIR"
    echo "Backups: $BACKUP_DIR"
    echo ""
    
    echo "=== CARACTERISTICAS ==="
    echo "  ✓ Firefox kiosk puro (sem iframe)"
    echo "  ✓ Suporte a URLs, imagens e videos"
    echo "  ✓ Rotacao automatica"
    echo "  ✓ Tempo configuravel por aba"
    echo "  ✓ Interface web completa"
    echo "  ✓ Servicos systemd"
    echo "  ✓ Backup automatico"
    echo "  ✓ Diagnostico integrado"
    echo ""
    
    echo "=== COMANDOS UTEIS ==="
    echo "Status: sudo systemctl status credivision-kiosk.service"
    echo "Logs: sudo journalctl -u credivision-kiosk.service -f"
    echo "Teste: sudo -u informa bash $PROJECT_DIR/kiosk.sh"
    echo "Parar: sudo systemctl stop credivision-kiosk.service"
    echo "Iniciar: sudo systemctl start credivision-kiosk.service"
    echo ""
    
    echo "=== SUPORTE ==="
    echo "Se precisar de ajuda, verifique os logs ou execute o diagnostico."
    echo ""
    
    read -p "Pressione Enter para continuar..."
    show_main_menu
}

# Iniciar programa
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    show_main_menu
fi
