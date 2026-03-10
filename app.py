"""
Sistema Kiosk - Interface Administrativa
Gerenciamento remoto de exibição em modo kiosk para TV
"""

import os
import json
import sqlite3
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

DB_PATH = os.environ.get('DB_PATH', '/data/kiosk.db')
CONFIG_PATH = os.environ.get('CONFIG_PATH', '/data/config.json')

# Configurações de upload
MEDIA_FOLDER = os.environ.get('MEDIA_FOLDER', os.path.expanduser('~/Documentos/kiosk-media'))
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'mp4', 'avi', 'mov', 'webm'}
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB

app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE
app.config['MEDIA_FOLDER'] = MEDIA_FOLDER


# ─── Database ────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    c = conn.cursor()
    c.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'viewer',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS tabs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            url TEXT,
            content_type TEXT NOT NULL DEFAULT 'url',
            file_path TEXT,
            duration INTEGER NOT NULL DEFAULT 300,
            active INTEGER NOT NULL DEFAULT 1,
            order_index INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user TEXT,
            action TEXT NOT NULL,
            details TEXT,
            ip TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
    """)

    # Default admin user
    admin_pass = hash_password(os.environ.get('ADMIN_PASSWORD', 'admin123'))
    try:
        c.execute(
            "INSERT OR IGNORE INTO users (username, password_hash, role) VALUES (?, ?, ?)",
            ('admin', admin_pass, 'admin')
        )
    except Exception:
        pass

    # Default tabs
    default_tabs = [
        ('Dashboard Principal', 'http://localhost:5000/display', 300, 1, 0),
        ('Notícias', 'https://g1.globo.com', 300, 1, 1),
        ('Tempo', 'https://weather.com/pt-BR', 300, 1, 2),
    ]
    for tab in default_tabs:
        try:
            c.execute(
                "INSERT OR IGNORE INTO tabs (name, url, duration, active, order_index) VALUES (?,?,?,?,?)",
                tab
            )
        except Exception:
            pass

    conn.commit()
    conn.close()


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


def ensure_media_folder():
    """Garante que a pasta de mídia exista"""
    os.makedirs(MEDIA_FOLDER, exist_ok=True)
    return MEDIA_FOLDER


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
        if 'user' not in session:
            return redirect(url_for('login'))
        if session.get('role') != 'admin':
            flash('Acesso restrito a administradores.', 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated


def log_action(action, details=None):
    conn = get_db()
    conn.execute(
        "INSERT INTO logs (user, action, details, ip) VALUES (?,?,?,?)",
        (session.get('user', 'system'), action, details, request.remote_addr)
    )
    conn.commit()
    conn.close()


# ─── Routes: Auth ─────────────────────────────────────────────────────────────

@app.route('/')
def index():
    if 'user' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        conn = get_db()
        user = conn.execute(
            "SELECT * FROM users WHERE username=? AND password_hash=?",
            (username, hash_password(password))
        ).fetchone()
        conn.close()

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


# ─── Routes: Dashboard ────────────────────────────────────────────────────────

@app.route('/dashboard')
@login_required
def dashboard():
    conn = get_db()
    tabs = conn.execute("SELECT * FROM tabs ORDER BY order_index").fetchall()
    logs = conn.execute(
        "SELECT * FROM logs ORDER BY created_at DESC LIMIT 20"
    ).fetchall()
    stats = {
        'total_tabs': conn.execute("SELECT COUNT(*) FROM tabs").fetchone()[0],
        'active_tabs': conn.execute("SELECT COUNT(*) FROM tabs WHERE active=1").fetchone()[0],
        'total_users': conn.execute("SELECT COUNT(*) FROM users").fetchone()[0],
    }
    conn.close()
    return render_template('dashboard.html', tabs=tabs, logs=logs, stats=stats)


# ─── Routes: Tabs ─────────────────────────────────────────────────────────────

@app.route('/tabs')
@login_required
def tabs_list():
    conn = get_db()
    tabs = conn.execute("SELECT * FROM tabs ORDER BY order_index").fetchall()
    conn.close()
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
            ensure_media_folder()
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
    
    conn = get_db()
    max_order = conn.execute("SELECT COALESCE(MAX(order_index),0) FROM tabs").fetchone()[0]
    conn.execute(
        "INSERT INTO tabs (name, url, content_type, file_path, duration, active, order_index) VALUES (?,?,?,?,?,?,?)",
        (name, final_url, content_type, file_path, duration, 1, max_order + 1)
    )
    conn.commit()
    conn.close()
    
    log_action('tab_add', f'Aba adicionada: {name} → {final_url} ({content_type})')
    flash(f'Aba "{name}" adicionada com sucesso.', 'success')
    return redirect(url_for('tabs_list'))


@app.route('/tabs/<int:tab_id>/toggle', methods=['POST'])
@admin_required
def tab_toggle(tab_id):
    conn = get_db()
    tab = conn.execute("SELECT * FROM tabs WHERE id=?", (tab_id,)).fetchone()
    if tab:
        new_state = 0 if tab['active'] else 1
        conn.execute("UPDATE tabs SET active=? WHERE id=?", (new_state, tab_id))
        conn.commit()
        log_action('tab_toggle', f'Aba {tab["name"]} → {"ativa" if new_state else "inativa"}')
    conn.close()
    return jsonify({'success': True})


@app.route('/tabs/<int:tab_id>/delete', methods=['POST'])
@admin_required
def tab_delete(tab_id):
    conn = get_db()
    tab = conn.execute("SELECT * FROM tabs WHERE id=?", (tab_id,)).fetchone()
    if tab:
        conn.execute("DELETE FROM tabs WHERE id=?", (tab_id,))
        conn.commit()
        log_action('tab_delete', f'Aba removida: {tab["name"]}')
    conn.close()
    flash('Aba removida.', 'success')
    return redirect(url_for('tabs_list'))


@app.route('/tabs/<int:tab_id>/edit', methods=['POST'])
@admin_required
def tab_edit(tab_id):
    name = request.form.get('name', '').strip()
    url = request.form.get('url', '').strip()
    duration = int(request.form.get('duration', 300))
    conn = get_db()
    conn.execute(
        "UPDATE tabs SET name=?, url=?, duration=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        (name, url, duration, tab_id)
    )
    conn.commit()
    conn.close()
    log_action('tab_edit', f'Aba {tab_id} editada: {name}')
    flash('Aba atualizada.', 'success')
    return redirect(url_for('tabs_list'))


@app.route('/tabs/reorder', methods=['POST'])
@admin_required
def tab_reorder():
    order = request.json.get('order', [])
    conn = get_db()
    for idx, tab_id in enumerate(order):
        conn.execute("UPDATE tabs SET order_index=? WHERE id=?", (idx, tab_id))
    conn.commit()
    conn.close()
    return jsonify({'success': True})


# ─── Routes: API (kiosk client) ───────────────────────────────────────────────

@app.route('/api/config')
def api_config():
    """Endpoint consumido pelo script kiosk para obter lista de abas."""
    conn = get_db()
    tabs = conn.execute(
        "SELECT id, name, url, content_type, duration FROM tabs WHERE active=1 ORDER BY order_index"
    ).fetchall()
    conn.close()
    return jsonify({
        'tabs': [dict(t) for t in tabs],
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


# ─── Routes: Users ────────────────────────────────────────────────────────────

@app.route('/users')
@admin_required
def users_list():
    conn = get_db()
    users = conn.execute("SELECT id, username, role, created_at FROM users").fetchall()
    conn.close()
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
    conn = get_db()
    try:
        conn.execute(
            "INSERT INTO users (username, password_hash, role) VALUES (?,?,?)",
            (username, hash_password(password), role)
        )
        conn.commit()
        log_action('user_add', f'Usuário criado: {username} ({role})')
        flash(f'Usuário "{username}" criado.', 'success')
    except sqlite3.IntegrityError:
        flash('Nome de usuário já existe.', 'error')
    conn.close()
    return redirect(url_for('users_list'))


@app.route('/users/<int:user_id>/delete', methods=['POST'])
@admin_required
def user_delete(user_id):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
    if user and user['username'] != 'admin':
        conn.execute("DELETE FROM users WHERE id=?", (user_id,))
        conn.commit()
        log_action('user_delete', f'Usuário removido: {user["username"]}')
        flash('Usuário removido.', 'success')
    else:
        flash('Não é possível remover o administrador principal.', 'error')
    conn.close()
    return redirect(url_for('users_list'))


# ─── Routes: Display (tela kiosk) ────────────────────────────────────────────

@app.route('/display')
def display():
    """Página de exibição padrão para o kiosk."""
    return render_template('display.html')


# ─── Routes: Logs ────────────────────────────────────────────────────────────

@app.route('/logs')
@admin_required
def logs_view():
    conn = get_db()
    logs = conn.execute(
        "SELECT * FROM logs ORDER BY created_at DESC LIMIT 100"
    ).fetchall()
    conn.close()
    return render_template('logs.html', logs=logs)


if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True, extra_files=['templates/tabs.html'])
