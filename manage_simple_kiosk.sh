#!/bin/bash

# CrediVision Management Script - Simple Kiosk Version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${SUDO_USER:-$USER}"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"

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

# Help function
show_help() {
    echo "CrediVision Management Script - Simple Kiosk"
    echo ""
    echo "Usage: sudo bash manage_simple_kiosk.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show application logs"
    echo "  logs-kiosk  Show kiosk logs"
    echo "  backup      Create backup"
    echo "  restore     Restore from backup"
    echo "  diagnose    Run system diagnostics"
    echo "  user-create Create admin user"
    echo "  user-list   List users"
    echo "  kiosk-test  Test kiosk in debug mode"
    echo "  kiosk-start Start kiosk manually"
    echo "  kiosk-stop  Stop kiosk manually"
    echo "  force-stop  Force stop everything"
    echo "  rebuild     Rebuild Docker image (no cache)"
    echo "  help        Show this help"
    echo ""
}

# Check if running as root for privileged commands
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This command requires sudo. Use: sudo bash manage_simple_kiosk.sh $1"
        exit 1
    fi
}

# Start services
start_services() {
    log_info "Starting CrediVision services..."
    
    # Start application
    log_info "Starting application service..."
    systemctl start credivision-app.service
    
    # Wait for application to be ready
    log_info "Waiting for application to start..."
    sleep 10
    
    # Test API
    if curl -s http://localhost:5000/api/config > /dev/null; then
        log_info "✓ Application is responding"
    else
        log_error "✗ Application is not responding"
        return 1
    fi
    
    # Start kiosk
    log_info "Starting kiosk service..."
    systemctl start credivision-kiosk.service
    
    log_info "Services started successfully"
}

# Stop services
stop_services() {
    log_info "Stopping CrediVision services..."
    
    # Stop kiosk first
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    
    # Stop application
    systemctl stop credivision-app.service 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -f simple_kiosk.sh 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    
    log_info "Services stopped"
}

# Restart services
restart_services() {
    log_info "Restarting CrediVision services..."
    stop_services
    sleep 3
    start_services
}

# Show status
show_status() {
    echo "=========================================="
    echo "CrediVision Service Status"
    echo "=========================================="
    echo ""
    
    # Application service
    echo "Application Service:"
    systemctl status credivision-app.service --no-pager -l | head -10
    echo ""
    
    # Kiosk service
    echo "Kiosk Service:"
    systemctl status credivision-kiosk.service --no-pager -l | head -10
    echo ""
    
    # Docker container
    echo "Docker Container:"
    if docker ps | grep -q credivision-app; then
        echo "✓ Container is running"
        docker ps | grep credivision-app
    else
        echo "✗ Container is not running"
    fi
    echo ""
    
    # API test
    echo "API Test:"
    if curl -s http://localhost:5000/api/config > /dev/null; then
        echo "✓ API is responding"
        curl -s http://localhost:5000/api/config | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Active tabs: {len(data.get(\"tabs\", []))}')
"
    else
        echo "✗ API is not responding"
    fi
    echo ""
    
    # Firefox processes
    echo "Firefox Processes:"
    if pgrep -f firefox > /dev/null; then
        echo "✓ Firefox is running"
        ps aux | grep firefox | grep -v grep | wc -l | xargs echo "  Processes:"
    else
        echo "✗ Firefox is not running"
    fi
    echo ""
}

# Show logs
show_logs() {
    echo "Application Logs (last 50 lines):"
    echo "=================================="
    docker logs credivision-app 2>/dev/null | tail -50 || echo "No logs available"
    echo ""
}

# Show kiosk logs
show_kiosk_logs() {
    echo "Kiosk Logs (last 50 lines):"
    echo "============================"
    journalctl -u credivision-kiosk.service -n 50 --no-pager
    echo ""
}

# Create backup
create_backup() {
    log_info "Creating backup..."
    
    BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"
    BACKUP_FILE="$BACKUP_DIR/manual_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup data and media
    tar -czf "$BACKUP_FILE" \
        -C "/home/$SERVICE_USER/Documents" \
        kiosk-data kiosk-media
    
    chown "$SERVICE_USER:$SERVICE_USER" "$BACKUP_FILE"
    
    log_info "Backup created: $BACKUP_FILE"
    
    # Show backup size
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup size: $SIZE"
}

# Restore backup
restore_backup() {
    log_info "Available backups:"
    
    BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "No backup directory found"
        return 1
    fi
    
    # List backups
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | while read -r line; do
        echo "$line"
    done
    
    echo ""
    read -p "Enter backup filename to restore: " BACKUP_FILE
    
    if [ ! -f "$BACKUP_FILE" ]; then
        log_error "Backup file not found: $BACKUP_FILE"
        return 1
    fi
    
    # Create current backup
    create_backup
    
    # Stop services
    stop_services
    
    # Restore
    log_info "Restoring from $BACKUP_FILE..."
    tar -xzf "$BACKUP_FILE" -C "/home/$SERVICE_USER/Documents/"
    
    # Fix permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "/home/$SERVICE_USER/Documents/kiosk-data"
    chown -R "$SERVICE_USER:$SERVICE_USER" "/home/$SERVICE_USER/Documents/kiosk-media"
    
    # Start services
    start_services
    
    log_info "Restore completed"
}

# Run diagnostics
run_diagnose() {
    echo "=========================================="
    echo "CrediVision System Diagnostics"
    echo "=========================================="
    echo ""
    
    # System info
    echo "System Information:"
    echo "=================="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "User: $SERVICE_USER"
    echo ""
    
    # Docker info
    echo "Docker Status:"
    echo "=============="
    if command -v docker &> /dev/null; then
        echo "✓ Docker is installed"
        docker --version
        echo ""
        echo "Docker Service:"
        systemctl is-active docker
        echo ""
        echo "Docker Containers:"
        docker ps -a
    else
        echo "✗ Docker is not installed"
    fi
    echo ""
    
    # Services
    echo "Systemd Services:"
    echo "================="
    for service in credivision-app credivision-kiosk credivision-backup; do
        status=$(systemctl is-active "$service.service" 2>/dev/null || echo "not-found")
        enabled=$(systemctl is-enabled "$service.service" 2>/dev/null || echo "not-found")
        echo "$service.service: $status (enabled: $enabled)"
    done
    echo ""
    
    # Network
    echo "Network Status:"
    echo "==============="
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "Port 5000:"
    if netstat -tlnp | grep -q ":5000"; then
        echo "✓ Port 5000 is listening"
        netstat -tlnp | grep ":5000"
    else
        echo "✗ Port 5000 is not listening"
    fi
    echo ""
    
    # API test
    echo "API Connectivity:"
    echo "================="
    if curl -s http://localhost:5000/api/config > /dev/null; then
        echo "✓ API is accessible"
        response=$(curl -s http://localhost:5000/api/config)
        echo "Active tabs: $(echo "$response" | python3 -c "import json, sys; print(len(json.load(sys.stdin).get('tabs', [])))" 2>/dev/null || echo "unknown")"
    else
        echo "✗ API is not accessible"
    fi
    echo ""
    
    # Disk space
    echo "Disk Usage:"
    echo "==========="
    df -h | grep -E "(Filesystem|/dev/)"
    echo ""
    echo "CrediVision directories:"
    for dir in kiosk-data kiosk-media kiosk-backups; do
        path="/home/$SERVICE_USER/Documents/$dir"
        if [ -d "$path" ]; then
            size=$(du -sh "$path" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        else
            echo "  $dir: not found"
        fi
    done
    echo ""
    
    # Firefox
    echo "Firefox Status:"
    echo "==============="
    if command -v firefox &> /dev/null; then
        echo "✓ Firefox is installed"
        firefox --version
        echo ""
        echo "Firefox Processes:"
        ps aux | grep firefox | grep -v grep | wc -l | xargs echo "  Processes:"
    else
        echo "✗ Firefox is not installed"
    fi
    echo ""
    
    # Dependencies
    echo "Dependencies:"
    echo "============="
    for cmd in xdotool python3 curl; do
        if command -v "$cmd" &> /dev/null; then
            echo "✓ $cmd is available"
        else
            echo "✗ $cmd is not available"
        fi
    done
    echo ""
}

# Create admin user
create_user() {
    log_info "Creating admin user..."
    
    echo "Enter username:"
    read -r username
    
    if [ -z "$username" ]; then
        log_error "Username cannot be empty"
        return 1
    fi
    
    echo "Enter password:"
    read -s password
    
    if [ -z "$password" ]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Hash password
    password_hash=$(echo -n "kiosk_salt_2024$password" | sha256sum | cut -d' ' -f1)
    
    # Add to users.json
    users_file="$DATA_DIR/users.json"
    
    if [ ! -f "$users_file" ]; then
        echo "[]" > "$users_file"
    fi
    
    # Create temp Python script
    python3 << EOF
import json

with open('$users_file', 'r') as f:
    users = json.load(f)

# Get next ID
max_id = max([user.get('id', 0) for user in users], default=0)
new_id = max_id + 1

# Add new user
new_user = {
    'id': new_id,
    'username': '$username',
    'password_hash': '$password_hash',
    'role': 'admin',
    'created_at': '$(date -Iseconds)'
}

users.append(new_user)

with open('$users_file', 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"User '{username}' created with ID {new_id}")
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" "$users_file"
    log_info "User '$username' created successfully"
}

# List users
list_users() {
    echo "Users:"
    echo "====="
    
    users_file="$DATA_DIR/users.json"
    
    if [ ! -f "$users_file" ]; then
        echo "No users file found"
        return 1
    fi
    
    python3 << EOF
import json

with open('$users_file', 'r') as f:
    users = json.load(f)

print(f"{'ID':<5} {'Username':<15} {'Role':<10} {'Created':<20}")
print("-" * 55)

for user in users:
    print(f"{user.get('id', 0):<5} {user.get('username', ''):<15} {user.get('role', ''):<10} {user.get('created_at', '')[:19]:<20}")
EOF
}

# Test kiosk
test_kiosk() {
    log_info "Testing kiosk in debug mode..."
    
    # Stop existing kiosk
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    pkill -f simple_kiosk.sh 2>/dev/null || true
    
    # Start in debug mode
    log_info "Starting kiosk in debug mode (windowed)..."
    sudo -u "$SERVICE_USER" "$PROJECT_DIR/simple_kiosk.sh" debug &
    
    log_info "Kiosk started in debug mode"
    log_info "Press Ctrl+C to stop"
    
    # Wait for interrupt
    trap 'pkill -f simple_kiosk.sh; log_info "Kiosk stopped"' INT
    wait
}

# Start kiosk manually
start_kiosk() {
    log_info "Starting kiosk manually..."
    
    # Stop existing
    systemctl stop credivision-kiosk.service 2>/dev/null || true
    pkill -f simple_kiosk.sh 2>/dev/null || true
    
    # Start in fullscreen
    sudo -u "$SERVICE_USER" "$PROJECT_DIR/simple_kiosk.sh" fullscreen &
    
    log_info "Kiosk started manually"
}

# Stop kiosk manually
stop_kiosk() {
    log_info "Stopping kiosk manually..."
    
    pkill -f simple_kiosk.sh 2>/dev/null || true
    pkill -f firefox 2>/dev/null || true
    
    log_info "Kiosk stopped"
}

# Force stop everything
force_stop_all() {
    log_info "Force stopping everything..."
    
    if [ -f "$PROJECT_DIR/force_stop_all.sh" ]; then
        bash "$PROJECT_DIR/force_stop_all.sh"
    else
        log_error "force_stop_all.sh not found"
        return 1
    fi
}

# Rebuild Docker image
rebuild_docker() {
    log_info "Rebuilding Docker image (no cache)..."
    
    cd "$PROJECT_DIR"
    
    # Stop services
    stop_services
    
    # Remove old image
    docker rmi -f credivision-app 2>/dev/null || true
    
    # Clean cache
    docker builder prune -a -f
    
    # Build new image
    docker build --no-cache --pull -f Dockerfile.production -t credivision-app .
    
    if [ $? -eq 0 ]; then
        log_info "✓ Docker image rebuilt successfully"
        
        # Start services
        start_services
    else
        log_error "✗ Failed to rebuild Docker image"
        return 1
    fi
}

# Main command handler
case "${1:-help}" in
    start)
        check_root
        start_services
        ;;
    stop)
        check_root
        stop_services
        ;;
    restart)
        check_root
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
        check_root
        create_backup
        ;;
    restore)
        check_root
        restore_backup
        ;;
    diagnose)
        run_diagnose
        ;;
    user-create)
        check_root
        create_user
        ;;
    user-list)
        list_users
        ;;
    kiosk-test)
        check_root
        test_kiosk
        ;;
    kiosk-start)
        check_root
        start_kiosk
        ;;
    kiosk-stop)
        check_root
        stop_kiosk
        ;;
    force-stop)
        check_root
        force_stop_all
        ;;
    rebuild)
        check_root
        rebuild_docker
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
