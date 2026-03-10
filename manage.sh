#!/bin/bash

# CrediVision Management Script
# This script provides management commands for the CrediVision system

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${SUDO_USER:-$USER}"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
show_usage() {
    echo "CrediVision Management Script"
    echo ""
    echo "Usage: sudo bash manage.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start           Start all services"
    echo "  stop            Stop all services"
    echo "  restart         Restart all services"
    echo "  status          Show status of all services"
    echo "  logs            Show application logs"
    echo "  logs-kiosk      Show kiosk logs"
    echo "  backup          Create manual backup"
    echo "  restore         Restore from backup"
    echo "  user-create     Create new admin user"
    echo "  user-list       List all users"
    echo "  diagnose        Run system diagnostics"
    echo "  update          Update application"
    echo "  help            Show this help message"
    echo ""
}

# Start services
start_services() {
    log_info "Starting CrediVision services..."
    systemctl start credivision-app.service
    sleep 5
    systemctl start credivision-kiosk.service
    log_info "Services started successfully"
}

# Stop services
stop_services() {
    log_info "Stopping CrediVision services..."
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-app.service
    log_info "Services stopped successfully"
}

# Restart services
restart_services() {
    log_info "Restarting CrediVision services..."
    systemctl restart credivision-app.service
    sleep 5
    systemctl restart credivision-kiosk.service
    log_info "Services restarted successfully"
}

# Show status
show_status() {
    echo "CrediVision System Status"
    echo "========================="
    echo ""
    
    echo "Services:"
    systemctl is-active credivision-app.service >/dev/null 2>&1 && \
        echo "  Application: ACTIVE" || echo "  Application: INACTIVE"
    systemctl is-active credivision-kiosk.service >/dev/null 2>&1 && \
        echo "  Kiosk: ACTIVE" || echo "  Kiosk: INACTIVE"
    systemctl is-active credivision-backup.timer >/dev/null 2>&1 && \
        echo "  Backup Timer: ACTIVE" || echo "  Backup Timer: INACTIVE"
    
    echo ""
    echo "Docker:"
    if docker ps | grep -q credivision-app; then
        echo "  Container: RUNNING"
        docker ps --format "  {{.Names}}: {{.Status}}" | grep credivision
    else
        echo "  Container: STOPPED"
    fi
    
    echo ""
    echo "Network:"
    if netstat -tlnp 2>/dev/null | grep -q ":5000 "; then
        echo "  Port 5000: IN USE"
    else
        echo "  Port 5000: FREE"
    fi
    
    echo ""
    echo "Storage:"
    echo "  Data: $(du -sh $DATA_DIR 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "  Media: $(du -sh $MEDIA_DIR 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "  Backups: $(du -sh $BACKUP_DIR 2>/dev/null | cut -f1 || echo 'N/A')"
    
    if [ -f "$DATA_DIR/tabs.json" ]; then
        TABS_COUNT=$(python3 -c "import json; print(len(json.load(open('$DATA_DIR/tabs.json'))))" 2>/dev/null || echo "0")
        echo "  Tabs configured: $TABS_COUNT"
    fi
    
    if [ -f "$DATA_DIR/users.json" ]; then
        USERS_COUNT=$(python3 -c "import json; print(len(json.load(open('$DATA_DIR/users.json'))))" 2>/dev/null || echo "0")
        echo "  Users: $USERS_COUNT"
    fi
}

# Show logs
show_logs() {
    log_info "Showing application logs (Ctrl+C to exit)..."
    journalctl -u credivision-app.service -f
}

# Show kiosk logs
show_kiosk_logs() {
    log_info "Showing kiosk logs (Ctrl+C to exit)..."
    journalctl -u credivision-kiosk.service -f
}

# Create backup
create_backup() {
    log_info "Creating manual backup..."
    
    BACKUP_FILE="$BACKUP_DIR/manual_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    tar -czf "$BACKUP_FILE" \
        -C /home/$SERVICE_USER/Documents kiosk-data kiosk-media \
        2>/dev/null
    
    if [ -f "$BACKUP_FILE" ]; then
        log_info "Backup created: $BACKUP_FILE"
        log_info "Size: $(du -h $BACKUP_FILE | cut -f1)"
    else
        log_error "Backup failed"
        exit 1
    fi
}

# Restore from backup
restore_backup() {
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
        log_error "No backups found in $BACKUP_DIR"
        exit 1
    }
    
    echo ""
    read -p "Enter backup filename to restore: " BACKUP_FILE
    
    if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_DIR/$BACKUP_FILE"
        exit 1
    fi
    
    log_warn "This will overwrite current data. Are you sure?"
    read -p "Type 'yes' to continue: " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Stopping services..."
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-app.service
    
    log_info "Creating backup of current state..."
    CURRENT_BACKUP="$BACKUP_DIR/before_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$CURRENT_BACKUP" \
        -C /home/$SERVICE_USER/Documents kiosk-data kiosk-media \
        2>/dev/null
    
    log_info "Restoring from backup..."
    tar -xzf "$BACKUP_DIR/$BACKUP_FILE" -C /home/$SERVICE_USER/Documents
    
    chown -R $SERVICE_USER:$SERVICE_USER "$DATA_DIR"
    chown -R $SERVICE_USER:$SERVICE_USER "$MEDIA_DIR"
    
    log_info "Starting services..."
    systemctl start credivision-app.service
    sleep 5
    systemctl start credivision-kiosk.service
    
    log_info "Restore completed successfully"
    log_info "Previous state backed up to: $CURRENT_BACKUP"
}

# Create new user
create_user() {
    echo "Create New Admin User"
    echo "===================="
    echo ""
    
    read -p "Username: " USERNAME
    read -s -p "Password: " PASSWORD
    echo ""
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        log_error "Username and password are required"
        exit 1
    fi
    
    python3 << EOF
import json
import hashlib
from datetime import datetime

username = "$USERNAME"
password = "$PASSWORD"
users_file = "$DATA_DIR/users.json"

password_hash = hashlib.sha256(f"kiosk_salt_2024{password}".encode()).hexdigest()
timestamp = datetime.utcnow().isoformat() + 'Z'

try:
    with open(users_file, 'r') as f:
        users = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    users = []

if any(u.get('username') == username for u in users):
    print(f"Error: User '{username}' already exists")
    exit(1)

new_user = {
    "id": max([u.get('id', 0) for u in users] + [0]) + 1,
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": timestamp
}
users.append(new_user)

with open(users_file, 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"User '{username}' created successfully")
EOF
    
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR/users.json"
}

# List users
list_users() {
    echo "System Users"
    echo "============"
    echo ""
    
    python3 << EOF
import json

users_file = "$DATA_DIR/users.json"

try:
    with open(users_file, 'r') as f:
        users = json.load(f)
    
    if users:
        print(f"{'ID':<5} {'Username':<20} {'Role':<10} {'Created':<25}")
        print("-" * 60)
        for user in sorted(users, key=lambda x: x.get('id', 0)):
            user_id = user.get('id', 'N/A')
            username = user.get('username', 'N/A')
            role = user.get('role', 'N/A')
            created = user.get('created_at', 'N/A')[:19]
            print(f"{user_id:<5} {username:<20} {role:<10} {created:<25}")
    else:
        print("No users found")
        
except (FileNotFoundError, json.JSONDecodeError):
    print("Error: Users file not found or corrupted")
EOF
}

# Run diagnostics
run_diagnostics() {
    echo "CrediVision System Diagnostics"
    echo "=============================="
    echo ""
    
    echo "System Information:"
    echo "  OS: $(lsb_release -d | cut -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Uptime: $(uptime -p)"
    echo ""
    
    echo "Services Status:"
    systemctl is-active credivision-app.service >/dev/null 2>&1 && \
        echo "  credivision-app: ACTIVE" || echo "  credivision-app: INACTIVE"
    systemctl is-active credivision-kiosk.service >/dev/null 2>&1 && \
        echo "  credivision-kiosk: ACTIVE" || echo "  credivision-kiosk: INACTIVE"
    systemctl is-active credivision-backup.timer >/dev/null 2>&1 && \
        echo "  credivision-backup.timer: ACTIVE" || echo "  credivision-backup.timer: INACTIVE"
    echo ""
    
    echo "Docker Status:"
    docker --version 2>/dev/null || echo "  Docker: NOT INSTALLED"
    docker compose version 2>/dev/null || echo "  Docker Compose: NOT INSTALLED"
    echo ""
    
    echo "Container Status:"
    if docker ps | grep -q credivision-app; then
        echo "  credivision-app: RUNNING"
        docker ps --format "  {{.Names}}: {{.Status}}" | grep credivision
    else
        echo "  credivision-app: STOPPED"
    fi
    echo ""
    
    echo "Directory Status:"
    [ -d "$PROJECT_DIR" ] && echo "  Project: EXISTS" || echo "  Project: MISSING"
    [ -d "$DATA_DIR" ] && echo "  Data: EXISTS" || echo "  Data: MISSING"
    [ -d "$MEDIA_DIR" ] && echo "  Media: EXISTS" || echo "  Media: MISSING"
    echo ""
    
    echo "File Status:"
    [ -f "$DATA_DIR/tabs.json" ] && echo "  tabs.json: EXISTS" || echo "  tabs.json: MISSING"
    [ -f "$DATA_DIR/users.json" ] && echo "  users.json: EXISTS" || echo "  users.json: MISSING"
    [ -f "$DATA_DIR/logs.json" ] && echo "  logs.json: EXISTS" || echo "  logs.json: MISSING"
    echo ""
    
    echo "Network Status:"
    netstat -tlnp 2>/dev/null | grep -q ":5000 " && \
        echo "  Port 5000: IN USE" || echo "  Port 5000: FREE"
    echo ""
    
    echo "API Status:"
    if curl -s --connect-timeout 5 http://localhost:5000/api/config >/dev/null 2>&1; then
        echo "  API: RESPONDING"
        TABS_COUNT=$(curl -s http://localhost:5000/api/config | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data.get('tabs', [])))" 2>/dev/null || echo "0")
        echo "  Active tabs: $TABS_COUNT"
    else
        echo "  API: NOT RESPONDING"
    fi
    echo ""
    
    echo "Firefox Status:"
    pgrep -f "firefox.*kiosk" >/dev/null && \
        echo "  Firefox Kiosk: RUNNING" || echo "  Firefox Kiosk: NOT RUNNING"
    echo ""
    
    echo "Recent Errors (last 10):"
    journalctl -u credivision-app.service -p err -n 10 --no-pager 2>/dev/null || \
        echo "  No recent errors"
}

# Update application
update_application() {
    log_info "Updating CrediVision application..."
    
    log_info "Pulling latest changes from repository..."
    cd "$PROJECT_DIR"
    git pull origin main || {
        log_warn "Git pull failed or not a git repository"
    }
    
    log_info "Stopping services..."
    systemctl stop credivision-kiosk.service
    systemctl stop credivision-app.service
    
    log_info "Rebuilding Docker image..."
    sudo -u $SERVICE_USER docker build -f Dockerfile.production -t credivision-app .
    
    log_info "Starting services..."
    systemctl start credivision-app.service
    sleep 5
    systemctl start credivision-kiosk.service
    
    log_info "Update completed successfully"
}

# Main command handler
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    logs-kiosk)
        show_kiosk_logs
        ;;
    backup)
        create_backup
        ;;
    restore)
        restore_backup
        ;;
    user-create)
        create_user
        ;;
    user-list)
        list_users
        ;;
    diagnose)
        run_diagnostics
        ;;
    update)
        update_application
        ;;
    help|*)
        show_usage
        ;;
esac
