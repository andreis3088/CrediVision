#!/bin/bash

# CrediVision Installation Script for Ubuntu
# This script installs and configures the CrediVision kiosk system
# Requirements: Ubuntu 20.04+ with sudo access

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration variables
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${SUDO_USER:-$USER}"
DATA_DIR="/home/$SERVICE_USER/Documents/kiosk-data"
MEDIA_DIR="/home/$SERVICE_USER/Documents/kiosk-media"
BACKUP_DIR="/home/$SERVICE_USER/Documents/kiosk-backups"
APP_PORT="5000"
KIOSK_DELAY="30"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use: sudo bash install.sh"
        exit 1
    fi
}

# Display banner
show_banner() {
    clear
    echo "=============================================="
    echo "  CrediVision Kiosk System - Installation"
    echo "=============================================="
    echo ""
    echo "This script will install and configure:"
    echo "- Docker and Docker Compose"
    echo "- CrediVision application"
    echo "- Firefox kiosk mode"
    echo "- Systemd services for auto-start"
    echo "- Data persistence in Documents folder"
    echo ""
}

# Update system
update_system() {
    log_step "Updating system packages..."
    apt update
    apt upgrade -y
    log_info "System updated successfully"
}

# Install dependencies
install_dependencies() {
    log_step "Installing system dependencies..."
    
    apt install -y \
        curl \
        wget \
        git \
        unzip \
        htop \
        nano \
        vim \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        firefox \
        zenity \
        x11-utils \
        x11-xserver-utils \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_info "Dependencies installed successfully"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    usermod -aG docker $SERVICE_USER
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    log_info "Docker installed and configured successfully"
}

# Create directory structure
create_directories() {
    log_step "Creating directory structure..."
    
    # Create main directories
    mkdir -p "$DATA_DIR"
    mkdir -p "$MEDIA_DIR/images"
    mkdir -p "$MEDIA_DIR/videos"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$PROJECT_DIR/logs"
    
    # Create initial JSON files if they don't exist
    if [ ! -f "$DATA_DIR/tabs.json" ]; then
        echo "[]" > "$DATA_DIR/tabs.json"
    fi
    
    if [ ! -f "$DATA_DIR/users.json" ]; then
        echo "[]" > "$DATA_DIR/users.json"
    fi
    
    if [ ! -f "$DATA_DIR/logs.json" ]; then
        echo "[]" > "$DATA_DIR/logs.json"
    fi
    
    # Set permissions
    chown -R $SERVICE_USER:$SERVICE_USER "$DATA_DIR"
    chown -R $SERVICE_USER:$SERVICE_USER "$MEDIA_DIR"
    chown -R $SERVICE_USER:$SERVICE_USER "$BACKUP_DIR"
    chown -R $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR"
    
    chmod 755 "$DATA_DIR"
    chmod 755 "$MEDIA_DIR"
    chmod 755 "$BACKUP_DIR"
    
    log_info "Directory structure created successfully"
}

# Configure environment
configure_environment() {
    log_step "Configuring environment variables..."
    
    SECRET_KEY=$(openssl rand -hex 32)
    
    cat > "$PROJECT_DIR/.env" << EOF
# CrediVision Environment Configuration
SECRET_KEY=$SECRET_KEY
ADMIN_PASSWORD=admin123
DATA_FOLDER=/data
MEDIA_FOLDER=/media
FLASK_ENV=production
APP_PORT=$APP_PORT

# Security settings
SESSION_TIMEOUT=3600
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900

# Upload settings
MAX_FILE_SIZE=104857600
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,mp4,avi,mov,webm

# File paths
TABS_FILE=/data/tabs.json
USERS_FILE=/data/users.json
LOGS_FILE=/data/logs.json
EOF
    
    chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/.env"
    chmod 600 "$PROJECT_DIR/.env"
    
    log_info "Environment configured successfully"
}

# Create Docker Compose file
create_docker_compose() {
    log_step "Creating Docker Compose configuration..."
    
    cat > "$PROJECT_DIR/docker-compose.yml" << EOF
version: "3.9"

services:
  credivision-app:
    build:
      context: .
      dockerfile: Dockerfile.production
    container_name: credivision-app
    environment:
      - DATA_FOLDER=/data
      - MEDIA_FOLDER=/media
      - SECRET_KEY=\${SECRET_KEY}
      - ADMIN_PASSWORD=\${ADMIN_PASSWORD}
      - FLASK_ENV=production
    ports:
      - "$APP_PORT:5000"
    volumes:
      - $DATA_DIR:/data:rw
      - $MEDIA_DIR:/media:rw
    restart: unless-stopped
    networks:
      - credivision-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/config"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  credivision-net:
    driver: bridge
EOF
    
    log_info "Docker Compose configuration created successfully"
}

# Create systemd service for application
create_app_service() {
    log_step "Creating systemd service for application..."
    
    cat > /etc/systemd/system/credivision-app.service << EOF
[Unit]
Description=CrediVision Kiosk Application
After=docker.service
Requires=docker.service
Documentation=file://$PROJECT_DIR/INSTALL.md

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Group=$SERVICE_USER
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
TimeoutStartSec=0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    log_info "Application service created successfully"
}

# Create systemd service for kiosk
create_kiosk_service() {
    log_step "Creating systemd service for Firefox kiosk..."
    
    cat > /etc/systemd/system/credivision-kiosk.service << EOF
[Unit]
Description=CrediVision Firefox Kiosk Display
After=credivision-app.service graphical.target
Wants=credivision-app.service
Documentation=file://$PROJECT_DIR/OPERATION.md

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStartPre=/bin/sleep $KIOSK_DELAY
ExecStart=/usr/bin/firefox --kiosk http://localhost:$APP_PORT/display --no-first-run --disable-pinch --disable-infobars --disable-session-crashed-bubble
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF
    
    log_info "Kiosk service created successfully"
}

# Create systemd timer for backup
create_backup_service() {
    log_step "Creating backup service and timer..."
    
    # Create backup script
    cat > "$PROJECT_DIR/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/$USER/Documents/kiosk-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/credivision_backup_$DATE.tar.gz"

echo "Creating backup: $BACKUP_FILE"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" \
    -C /home/$USER/Documents kiosk-data kiosk-media \
    2>/dev/null

if [ -f "$BACKUP_FILE" ]; then
    echo "Backup created successfully: $BACKUP_FILE"
    echo "Size: $(du -h $BACKUP_FILE | cut -f1)"
    
    # Keep only last 7 backups
    find "$BACKUP_DIR" -name "credivision_backup_*.tar.gz" -mtime +7 -delete
    echo "Old backups cleaned up"
else
    echo "Backup failed"
    exit 1
fi
EOF
    
    chmod +x "$PROJECT_DIR/backup.sh"
    chown $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR/backup.sh"
    
    # Create systemd service
    cat > /etc/systemd/system/credivision-backup.service << EOF
[Unit]
Description=CrediVision Backup Service
After=credivision-app.service

[Service]
Type=oneshot
User=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/backup.sh
StandardOutput=journal
StandardError=journal
EOF
    
    # Create systemd timer
    cat > /etc/systemd/system/credivision-backup.timer << EOF
[Unit]
Description=Daily CrediVision Backup
Requires=credivision-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    log_info "Backup service and timer created successfully"
}

# Enable and start services
enable_services() {
    log_step "Enabling systemd services..."
    
    systemctl daemon-reload
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl enable credivision-backup.timer
    
    log_info "Services enabled successfully"
}

# Build Docker image
build_docker_image() {
    log_step "Building Docker image..."
    
    cd "$PROJECT_DIR"
    sudo -u $SERVICE_USER docker build -f Dockerfile.production -t credivision-app .
    
    log_info "Docker image built successfully"
}

# Start services
start_services() {
    log_step "Starting CrediVision services..."
    
    systemctl start credivision-app.service
    
    log_info "Waiting for application to start..."
    sleep 20
    
    # Check if service is running
    if systemctl is-active --quiet credivision-app.service; then
        log_info "Application service started successfully"
    else
        log_warn "Application service may not have started correctly"
        log_warn "Check logs with: journalctl -u credivision-app.service -f"
    fi
}

# Create admin user
create_admin_user() {
    log_step "Creating default admin user..."
    
    python3 << EOF
import json
import hashlib
from datetime import datetime

username = "admin"
password = "admin123"
users_file = "$DATA_DIR/users.json"

password_hash = hashlib.sha256(f"kiosk_salt_2024{password}".encode()).hexdigest()
timestamp = datetime.utcnow().isoformat() + 'Z'

try:
    with open(users_file, 'r') as f:
        users = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    users = []

users = [u for u in users if u.get('username') != username]

new_admin = {
    "id": max([u.get('id', 0) for u in users] + [0]) + 1,
    "username": username,
    "password_hash": password_hash,
    "role": "admin",
    "created_at": timestamp
}
users.append(new_admin)

with open(users_file, 'w') as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print(f"Admin user created: {username}")
EOF
    
    chown $SERVICE_USER:$SERVICE_USER "$DATA_DIR/users.json"
    chmod 644 "$DATA_DIR/users.json"
    
    log_info "Admin user created successfully"
}

# Configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow $APP_PORT/tcp
        ufw --force enable
        log_info "Firewall configured successfully"
    else
        log_warn "UFW not found, skipping firewall configuration"
    fi
}

# Display summary
show_summary() {
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    echo "  Installation Completed Successfully"
    echo "=============================================="
    echo ""
    echo "System Information:"
    echo "  Project Directory: $PROJECT_DIR"
    echo "  Data Directory: $DATA_DIR"
    echo "  Media Directory: $MEDIA_DIR"
    echo "  Backup Directory: $BACKUP_DIR"
    echo ""
    echo "Access Information:"
    echo "  Admin Interface: http://$IP_ADDRESS:$APP_PORT"
    echo "  Kiosk Display: http://$IP_ADDRESS:$APP_PORT/display"
    echo ""
    echo "Default Credentials:"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo "  WARNING: Change the default password after first login"
    echo ""
    echo "Service Management:"
    echo "  Start app: sudo systemctl start credivision-app"
    echo "  Stop app: sudo systemctl stop credivision-app"
    echo "  Start kiosk: sudo systemctl start credivision-kiosk"
    echo "  Stop kiosk: sudo systemctl stop credivision-kiosk"
    echo "  View logs: sudo journalctl -u credivision-app -f"
    echo ""
    echo "Auto-start Configuration:"
    echo "  Application: Enabled (starts with system)"
    echo "  Kiosk: Enabled (starts with graphical session)"
    echo "  Backup: Enabled (daily at midnight)"
    echo ""
    echo "Next Steps:"
    echo "  1. Access the admin interface at http://$IP_ADDRESS:$APP_PORT"
    echo "  2. Login with default credentials"
    echo "  3. Change the admin password"
    echo "  4. Configure your first tab (URL, image, or video)"
    echo "  5. Restart the system to test auto-start"
    echo ""
    echo "For more information, see:"
    echo "  - INSTALL.md for installation details"
    echo "  - OPERATION.md for operation and maintenance"
    echo "  - README.md for system overview"
    echo ""
}

# Main installation flow
main() {
    show_banner
    check_root
    
    log_info "Starting installation process..."
    
    update_system
    install_dependencies
    install_docker
    create_directories
    configure_environment
    create_docker_compose
    create_app_service
    create_kiosk_service
    create_backup_service
    enable_services
    build_docker_image
    start_services
    create_admin_user
    configure_firewall
    
    show_summary
    
    echo "Installation completed. System is ready to use."
    echo ""
    read -p "Would you like to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebooting system in 5 seconds..."
        sleep 5
        reboot
    else
        log_info "Please reboot the system manually to complete setup"
    fi
}

# Run main installation
main
