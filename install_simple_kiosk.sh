#!/bin/bash

# CrediVision Installation Script with Simple Kiosk
# Instalação completa com Simple Kiosk (sem iframe)

set -e

# Colors for output
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
        log_error "This script must be run as root. Use: sudo bash install_simple_kiosk.sh"
        exit 1
    fi
}

# Display banner
display_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    CrediVision - Simple Kiosk Installer"
    echo "=========================================="
    echo -e "${NC}"
    echo "This script will install:"
    echo "  • Docker and Docker Compose"
    echo "  • CrediVision Flask Application"
    echo "  • Simple Kiosk (sem iframe)"
    echo "  • Systemd Services"
    echo "  • Firefox with xdotool"
    echo ""
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "This script is designed for Ubuntu systems"
        exit 1
    fi
    
    # Check if user exists
    if ! id "$SERVICE_USER" &>/dev/null; then
        log_error "User $SERVICE_USER does not exist"
        exit 1
    fi
    
    log_info "System requirements verified"
}

# Update system
update_system() {
    log_step "Updating system packages..."
    apt update
    apt upgrade -y
    log_info "System updated"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add user to docker group
    usermod -aG docker "$SERVICE_USER"
    
    log_info "Docker installed"
}

# Install Docker Compose
install_docker_compose() {
    log_step "Installing Docker Compose..."
    
    # Remove old version
    rm -f /usr/local/bin/docker-compose
    
    # Install latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    log_info "Docker Compose installed"
}

# Install Firefox and dependencies
install_firefox() {
    log_step "Installing Firefox and dependencies..."
    
    # Install Firefox
    apt install -y firefox
    
    # Install xdotool for window management
    apt install -y xdotool
    
    # Install additional dependencies
    apt install -y \
        python3-requests \
        notify-send \
        xvfb \
        x11-utils
    
    log_info "Firefox and dependencies installed"
}

# Create directories
create_directories() {
    log_step "Creating directories..."
    
    mkdir -p "$DATA_DIR"
    mkdir -p "$MEDIA_DIR/images"
    mkdir -p "$MEDIA_DIR/videos"
    mkdir -p "$BACKUP_DIR"
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$MEDIA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
    
    log_info "Directories created"
}

# Create initial data files
create_initial_data() {
    log_step "Creating initial data files..."
    
    # Create tabs.json
    cat > "$DATA_DIR/tabs.json" << 'EOF'
[]
EOF
    
    # Create users.json with admin user
    cat > "$DATA_DIR/users.json" << 'EOF'
[
  {
    "id": 1,
    "username": "admin",
    "password_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "role": "admin",
    "created_at": "2024-01-01T00:00:00"
  }
]
EOF
    
    # Create logs.json
    cat > "$DATA_DIR/logs.json" << 'EOF'
[]
EOF
    
    # Set permissions
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"/*.json
    
    log_info "Initial data files created"
}

# Build Docker image (NO CACHE)
build_docker_image() {
    log_step "Building Docker image (NO CACHE)..."
    
    cd "$PROJECT_DIR"
    
    # Remove any existing image
    docker rmi -f credivision-app 2>/dev/null || true
    
    # Clean Docker cache completely
    docker builder prune -a -f
    docker system prune -f
    
    # Build without any cache
    log_info "Building image (this may take 5-10 minutes)..."
    docker build --no-cache --pull -f Dockerfile.production -t credivision-app .
    
    if [ $? -eq 0 ]; then
        log_info "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Create systemd services
create_systemd_services() {
    log_step "Creating systemd services..."
    
    # Create app service
    cat > /etc/systemd/system/credivision-app.service << EOF
[Unit]
Description=CrediVision Flask Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
User=$SERVICE_USER
Environment=DATA_FOLDER=$DATA_DIR
Environment=MEDIA_FOLDER=$MEDIA_DIR
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Create simple kiosk service
    cat > /etc/systemd/system/credivision-kiosk.service << EOF
[Unit]
Description=CrediVision Simple Kiosk
After=credivision-app.service
Wants=credivision-app.service

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
ExecStartPre=/bin/sleep $KIOSK_DELAY
ExecStart=$PROJECT_DIR/simple_kiosk.sh fullscreen
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Create backup service
    cat > /etc/systemd/system/credivision-backup.service << EOF
[Unit]
Description=CrediVision Backup Service

[Service]
Type=oneshot
User=$SERVICE_USER
ExecStart=$PROJECT_DIR/manage.sh backup

[Install]
WantedBy=multi-user.target
EOF
    
    # Create backup timer
    cat > /etc/systemd/system/credivision-backup.timer << EOF
[Unit]
Description=Run CrediVision backup daily
Requires=credivision-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable credivision-app.service
    systemctl enable credivision-kiosk.service
    systemctl enable credivision-backup.timer
    
    log_info "Systemd services created and enabled"
}

# Setup permissions
setup_permissions() {
    log_step "Setting up permissions..."
    
    # Set project directory permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
    chmod +x "$PROJECT_DIR"/*.sh
    
    # Setup X11 permissions
    usermod -a -G input "$SERVICE_USER"
    usermod -a -G video "$SERVICE_USER"
    
    log_info "Permissions configured"
}

# Configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    # Install UFW if not present
    apt install -y ufw
    
    # Configure basic firewall
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow $APP_PORT/tcp
    
    # Enable firewall
    ufw --force enable
    
    log_info "Firewall configured"
}

# Test installation
test_installation() {
    log_step "Testing installation..."
    
    # Start services
    systemctl start credivision-app.service
    sleep 10
    
    # Test API
    if curl -s "http://localhost:$APP_PORT/api/config" > /dev/null; then
        log_info "✓ API responding correctly"
    else
        log_error "✗ API not responding"
        return 1
    fi
    
    # Test Docker container
    if docker ps | grep -q "credivision-app"; then
        log_info "✓ Docker container running"
    else
        log_error "✗ Docker container not running"
        return 1
    fi
    
    log_info "Installation test completed"
}

# Display final information
display_final_info() {
    echo ""
    echo -e "${GREEN}=========================================="
    echo "        Installation Completed!"
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo "System Information:"
    echo "  • Application URL: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
    echo "  • Default Login: admin / admin123"
    echo "  • Data Directory: $DATA_DIR"
    echo "  • Media Directory: $MEDIA_DIR"
    echo ""
    echo "Services Status:"
    echo "  • credivision-app: $(systemctl is-active credivision-app.service)"
    echo "  • credivision-kiosk: $(systemctl is-active credivision-kiosk.service)"
    echo "  • credivision-backup: $(systemctl is-enabled credivision-backup.timer)"
    echo ""
    echo "Useful Commands:"
    echo "  • Check status: sudo bash $PROJECT_DIR/manage.sh status"
    echo "  • View logs: sudo bash $PROJECT_DIR/manage.sh logs"
    echo "  • Test kiosk: sudo -u $SERVICE_USER $PROJECT_DIR/simple_kiosk.sh debug"
    echo "  • Force stop: sudo bash $PROJECT_DIR/force_stop_all.sh"
    echo ""
    echo "Next Steps:"
    echo "  1. Reboot the system: sudo reboot"
    echo "  2. Wait 2-3 minutes for services to start"
    echo "  3. Access the web interface"
    echo "  4. Add your content (URLs, images, videos)"
    echo "  5. Change default password!"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Change the default admin password immediately!${NC}"
    echo ""
}

# Main installation flow
main() {
    check_root
    display_banner
    check_requirements
    update_system
    install_docker
    install_docker_compose
    install_firefox
    create_directories
    create_initial_data
    build_docker_image
    create_systemd_services
    setup_permissions
    configure_firewall
    test_installation
    display_final_info
}

# Run main function
main "$@"
