#!/usr/bin/env python3
"""
CrediVision - Sistema Kiosk SEM BANCO DE DADOS
Armazenamento em arquivos JSON locais
"""

import os
import json
import hashlib
import secrets
from datetime import datetime
from functools import wraps
from werkzeug.utils import secure_filename
from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, flash, send_file
)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', secrets.token_hex(32))

# Configurações de arquivos (sem banco de dados)
DATA_FOLDER = os.environ.get('DATA_FOLDER', os.path.expanduser('~/Documentos/kiosk-data'))
MEDIA_FOLDER = os.environ.get('MEDIA_FOLDER', os.path.expanduser('~/Documentos/kiosk-media'))
TABS_FILE = os.path.join(DATA_FOLDER, 'tabs.json')
USERS_FILE = os.path.join(DATA_FOLDER, 'users.json')
LOGS_FILE = os.path.join(DATA_FOLDER, 'logs.json')

# Configurações de upload
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'mp4', 'avi', 'mov', 'webm'}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB

app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE
app.config['MEDIA_FOLDER'] = MEDIA_FOLDER

# ─── Funções de Arquivo ─────────────────────────────────────────────────────────────

def ensure_data_folders():
    """Garante que as pastas de dados existam"""
    os.makedirs(DATA_FOLDER, exist_ok=True)
    os.makedirs(MEDIA_FOLDER, exist_ok=True)
    
    # Criar arquivos JSON se não existirem
    if not os.path.exists(TABS_FILE):
        save_json(TABS_FILE, [])
    if not os.path.exists(USERS_FILE):
        save_json(USERS_FILE, [
            {
                'id': 1,
                'username': 'admin',
                'password_hash': hash_password('admin123'),
                'role': 'admin',
                'created_at': datetime.now().isoformat()
            }
        ])
    if not os.path.exists(LOGS_FILE):
        save_json(LOGS_FILE, [])

def load_json(file_path):
    """Carrega dados de arquivo JSON"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_json(file_path, data):
    """Salva dados em arquivo JSON"""
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def get_next_id(data_list):
    """Gera próximo ID para lista de dados"""
    if not data_list:
        return 1
    return max(item.get('id', 0) for item in data_list) + 1

# ─── Funções Auxiliares ─────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    salt = "kiosk_salt_2024"
    return hashlib.sha256(f"{salt}{password}".encode()).hexdigest()

def allowed_file(filename: str) -> bool:
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_content_type(filename: str) -> str:
    """Determina o tipo de conteúdo baseado na extensão"""
    ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
    if ext in ['png', 'jpg', 'jpeg', 'gif']:
        return 'image'
    elif ext in ['mp4', 'avi', 'mov', 'webm']:
        return 'video'
    else:
        return 'url'

def log_action(action: str, details: str = ""):
    """Registra ação no log"""
    logs = load_json(LOGS_FILE)
    log_entry = {
        'id': get_next_id(logs),
        'user': session.get('user', 'system'),
        'action': action,
        'details': details,
        'ip': request.remote_addr,
        'created_at': datetime.now().isoformat()
    }
    logs.append(log_entry)
    
    # Manter apenas últimos 1000 logs
    if len(logs) > 1000:
        logs = logs[-1000:]
    
    save_json(LOGS_FILE, logs)

# ─── Auth ─────────────────────────────────────────────────────────────────────

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session or session.get('role') != 'admin':
            flash('Acesso restrito a administradores.', 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated

# ─── Routes: Auth ───────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        
        users = load_json(USERS_FILE)
        user = None
        for u in users:
            if u['username'] == username and u['password_hash'] == hash_password(password):
                user = u
                break
        
        if user:
            session['user'] = user['username']
            session['role'] = user['role']
            log_action('login', f'Login bem-sucedido')
            return redirect(url_for('dashboard'))
        else:
            flash('Usuário ou senha inválidos.', 'error')

    return render_template('login.html')

@app.route('/logout')
def logout():
    log_action('logout')
    session.clear()
    return redirect(url_for('login'))

# ─── Routes: Dashboard ───────────────────────────────────────────────────────────

@app.route('/dashboard')
@login_required
def dashboard():
    tabs = load_json(TABS_FILE)
    logs = load_json(LOGS_FILE)
    
    # Estatísticas
    stats = {
        'total_tabs': len(tabs),
        'active_tabs': len([t for t in tabs if t.get('active', True)]),
        'total_users': len(load_json(USERS_FILE)),
        'total_logs': len(logs)
    }
    
    # Logs recentes
    recent_logs = logs[-10:] if logs else []
    
    return render_template('dashboard.html', tabs=tabs, logs=recent_logs, stats=stats)

# ─── Routes: Tabs ───────────────────────────────────────────────────────────────

@app.route('/tabs')
@login_required
def tabs_list():
    tabs = load_json(TABS_FILE)
    return render_template('tabs.html', tabs=tabs)

@app.route('/tabs/add', methods=['POST'])
@admin_required
def tab_add():
    name = request.form.get('name', '').strip()
    url = request.form.get('url', '').strip()
    duration = int(request.form.get('duration', 300))
    content_type = request.form.get('content_type', 'url')
    
    if not name:
        flash('Nome é obrigatório.', 'error')
        return redirect(url_for('tabs_list'))
    
    # Determinar tipo de conteúdo e URL/caminho do arquivo
    file_path = None
    final_url = url
    
    if content_type == 'file' and 'file' in request.files:
        file = request.files['file']
        if file and file.filename and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            file_path = os.path.join(MEDIA_FOLDER, filename)
            file.save(file_path)
            final_url = f"/media/{filename}"
            content_type = get_content_type(filename)
        else:
            flash('Arquivo inválido ou não selecionado.', 'error')
            return redirect(url_for('tabs_list'))
    elif content_type == 'url' and not url:
        flash('URL é obrigatória para tipo URL.', 'error')
        return redirect(url_for('tabs_list'))
    
    # Carregar abas existentes
    tabs = load_json(TABS_FILE)
    
    # Nova aba
    new_tab = {
        'id': get_next_id(tabs),
        'name': name,
        'url': final_url,
        'content_type': content_type,
        'file_path': file_path,
        'duration': duration,
        'active': True,
        'order_index': len(tabs),
        'created_at': datetime.now().isoformat(),
        'updated_at': datetime.now().isoformat()
    }
    
    tabs.append(new_tab)
    save_json(TABS_FILE, tabs)
    
    log_action('tab_add', f'Aba adicionada: {name} → {final_url} ({content_type})')
    flash(f'Aba "{name}" adicionada com sucesso.', 'success')
    return redirect(url_for('tabs_list'))

@app.route('/tabs/<int:tab_id>/toggle', methods=['POST'])
@admin_required
def tab_toggle(tab_id):
    tabs = load_json(TABS_FILE)
    
    for tab in tabs:
        if tab['id'] == tab_id:
            tab['active'] = not tab['active']
            tab['updated_at'] = datetime.now().isoformat()
            status = 'ativada' if tab['active'] else 'desativada'
            log_action('tab_toggle', f'Aba "{tab["name"]}" {status}')
            flash(f'Aba "{tab["name"]}" {status}.', 'success')
            break
    
    save_json(TABS_FILE, tabs)
    return redirect(url_for('tabs_list'))

@app.route('/tabs/<int:tab_id>/delete', methods=['POST'])
@admin_required
def tab_delete(tab_id):
    tabs = load_json(TABS_FILE)
    
    for i, tab in enumerate(tabs):
        if tab['id'] == tab_id:
            # Excluir arquivo se existir
            if tab.get('file_path') and os.path.exists(tab['file_path']):
                os.remove(tab['file_path'])
                log_action('file_deleted', f'Arquivo excluído: {tab["file_path"]}')
            
            # Remover aba
            tab_name = tab['name']
            tabs.pop(i)
            save_json(TABS_FILE, tabs)
            
            log_action('tab_delete', f'Aba "{tab_name}" removida')
            flash(f'Aba "{tab_name}" removida com sucesso.', 'success')
            break
    
    return redirect(url_for('tabs_list'))

@app.route('/tabs/delete_file/<int:tab_id>', methods=['POST'])
@admin_required
def delete_file_only(tab_id):
    """Excluir apenas o arquivo, mantendo a aba"""
    tabs = load_json(TABS_FILE)
    
    for tab in tabs:
        if tab['id'] == tab_id and tab.get('file_path'):
            if os.path.exists(tab['file_path']):
                os.remove(tab['file_path'])
                
                # Atualizar aba para modo URL
                tab['content_type'] = 'url'
                tab['url'] = ''
                tab['file_path'] = None
                tab['updated_at'] = datetime.now().isoformat()
                
                save_json(TABS_FILE, tabs)
                
                log_action('file_deleted', f'Arquivo excluído da aba "{tab["name"]}"')
                flash(f'Arquivo da aba "{tab["name"]}" excluído com sucesso.', 'success')
            break
    
    return redirect(url_for('tabs_list'))

@app.route('/tabs/<int:tab_id>/edit', methods=['POST'])
@admin_required
def tab_edit(tab_id):
    name = request.form.get('name', '').strip()
    url = request.form.get('url', '').strip()
    duration = int(request.form.get('duration', 300))
    
    if not name or not url:
        flash('Nome e URL são obrigatórios.', 'error')
        return redirect(url_for('tabs_list'))
    
    tabs = load_json(TABS_FILE)
    
    for tab in tabs:
        if tab['id'] == tab_id:
            tab['name'] = name
            tab['url'] = url
            tab['duration'] = duration
            tab['updated_at'] = datetime.now().isoformat()
            log_action('tab_edit', f'Aba atualizada: {name}')
            flash(f'Aba "{name}" atualizada com sucesso.', 'success')
            break
    
    save_json(TABS_FILE, tabs)
    return redirect(url_for('tabs_list'))

@app.route('/tabs/reorder', methods=['POST'])
@admin_required
def tab_reorder():
    data = request.json or {}
    order = data.get('order', [])
    
    tabs = load_json(TABS_FILE)
    tabs_dict = {tab['id']: tab for tab in tabs}
    
    for idx, tab_id in enumerate(order):
        if tab_id in tabs_dict:
            tabs_dict[tab_id]['order_index'] = idx
            tabs_dict[tab_id]['updated_at'] = datetime.now().isoformat()
    
    # Reordenar lista
    tabs = [tabs_dict[int(tab_id)] for tab_id in order if int(tab_id) in tabs_dict]
    save_json(TABS_FILE, tabs)
    
    log_action('tab_reorder', f'Abas reordenadas')
    return jsonify({'success': True})

# ─── Routes: Users ───────────────────────────────────────────────────────────────

@app.route('/users')
@login_required
@admin_required
def users_list():
    users = load_json(USERS_FILE)
    return render_template('users.html', users=users)

@app.route('/users/add', methods=['POST'])
@admin_required
def user_add():
    username = request.form.get('username', '').strip()
    password = request.form.get('password', '')
    role = request.form.get('role', 'viewer')
    
    if not username or not password:
        flash('Usuário e senha são obrigatórios.', 'error')
        return redirect(url_for('users_list'))
    
    users = load_json(USERS_FILE)
    
    # Verificar se usuário já existe
    for user in users:
        if user['username'] == username:
            flash('Usuário já existe.', 'error')
            return redirect(url_for('users_list'))
    
    # Novo usuário
    new_user = {
        'id': get_next_id(users),
        'username': username,
        'password_hash': hash_password(password),
        'role': role,
        'created_at': datetime.now().isoformat()
    }
    
    users.append(new_user)
    save_json(USERS_FILE, users)
    
    log_action('user_add', f'Usuário adicionado: {username}')
    flash(f'Usuário "{username}" adicionado com sucesso.', 'success')
    return redirect(url_for('users_list'))

@app.route('/users/<int:user_id>/delete', methods=['POST'])
@admin_required
def user_delete(user_id):
    users = load_json(USERS_FILE)
    
    for i, user in enumerate(users):
        if user['id'] == user_id:
            username = user['username']
            users.pop(i)
            save_json(USERS_FILE, users)
            
            log_action('user_delete', f'Usuário removido: {username}')
            flash(f'Usuário "{username}" removido com sucesso.', 'success')
            break
    
    return redirect(url_for('users_list'))

# ─── Routes: Logs ───────────────────────────────────────────────────────────────

@app.route('/logs')
@login_required
@admin_required
def logs_list():
    logs = load_json(LOGS_FILE)
    return render_template('logs.html', logs=logs)

# ─── Routes: Display ─────────────────────────────────────────────────────────────

@app.route('/display')
def display():
    return render_template('display.html')

# ─── Routes: API (kiosk client) ───────────────────────────────────────────────────

@app.route('/api/config')
def api_config():
    """Endpoint consumido pelo script kiosk para obter lista de abas."""
    tabs = load_json(TABS_FILE)
    active_tabs = [tab for tab in tabs if tab.get('active', True)]
    active_tabs.sort(key=lambda x: x.get('order_index', 0))
    
    return jsonify({
        'tabs': active_tabs,
        'updated_at': datetime.now().isoformat()
    })

@app.route('/api/status', methods=['POST'])
def api_status():
    """Recebe heartbeat do kiosk."""
    data = request.json or {}
    log_action('kiosk_heartbeat', json.dumps(data))
    return jsonify({'status': 'ok', 'timestamp': datetime.now().isoformat()})

@app.route('/media/<filename>')
def serve_media(filename):
    """Serve arquivos de mídia (imagens e vídeos)"""
    file_path = os.path.join(MEDIA_FOLDER, filename)
    if os.path.exists(file_path) and allowed_file(filename):
        return send_file(file_path)
    else:
        return "Arquivo não encontrado", 404

@app.route('/api/update-webhook', methods=['POST'])
@login_required
def update_webhook():
    """Webhook para notificar mudanças nas abas"""
    try:
        data = request.json or {}
        action = data.get('action', 'update')
        
        # Registrar ação
        log_action(f'webhook_{action}', f"Webhook recebido: {json.dumps(data)}")
        
        # Notificar atualizador automático (se estiver rodando)
        try:
            import requests
            requests.post('http://localhost:5001/webhook', 
                         json={'action': action, 'timestamp': datetime.now().isoformat()},
                         timeout=2)
        except:
            pass  # Ignorar se atualizador não estiver rodando
        
        return jsonify({'status': 'ok', 'message': 'Webhook processado'})
        
    except Exception as e:
        log_action('webhook_error', str(e))
        return jsonify({'error': str(e)}), 500

# ─── Inicialização ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    ensure_data_folders()
    app.run(host='0.0.0.0', port=5000, debug=True)
