#!/bin/bash

# setup_popcache_node.sh
# Script to set up and configure a POP Cache Node for Pipe Network Testnet

# Exit on any error
set -e

# Variables
INSTALL_DIR="/opt/popcache"
CONFIG_FILE="$INSTALL_DIR/config.json"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Use sudo."
  exit 1
fi

echo "Starting POP Cache Node setup..."

# Prompt for user input
echo "Please enter the following details:"
read -p "Invite Code: " INVITE_CODE
read -p "Solana Wallet Address (for rewards): " SOLANA_PUBKEY
read -p "Node Name: " NODE_NAME
read -p "POP Name: " POP_NAME
read -p "Location (e.g., Your Location, Country): " LOCATION
read -p "Email: " EMAIL
read -p "Website (e.g., https://your-website.com): " WEBSITE
read -p "Discord Username: " DISCORD
read -p "Telegram Handle: " TELEGRAM

# Validate required inputs
if [ -z "$INVITE_CODE" ] || [ -z "$SOLANA_PUBKEY" ] || [ -z "$NODE_NAME" ] || [ -z "$POP_NAME" ] || [ -z "$LOCATION" ] || [ -z "$EMAIL" ]; then
  echo "Error: All fields except Website, Discord, and Telegram are required."
  exit 1
fi

# 1. Prepare System
echo "Preparing system..."

# Update and install dependencies
apt update
apt install -y libssl-dev ca-certificates curl nano

# Create dedicated user
if ! id "popcache" >/dev/null 2>&1; then
  useradd -m -s /bin/bash popcache
  usermod -aG sudo popcache
fi

# Optimize system settings
cat > /etc/sysctl.d/99-popcache.conf << EOL
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL

sysctl -p /etc/sysctl.d/99-popcache.conf

# Increase file limits
cat > /etc/security/limits.d/popcache.conf << EOL
*    hard nofile 65535
*    soft nofile 65535
EOL

# 2. Installation
echo "Installing POP Cache Node..."

# Create installation directory
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/logs"
chown -R popcache:popcache "$INSTALL_DIR"

# Download binary (requires invite code)
# Note: Replace with actual download URL provided in email
echo "Please ensure you have the binary download URL from your invite email."
# Example: wget "https://download.pipe.network/popcache?code=$INVITE_CODE" -O "$INSTALL_DIR/pop"
# For now, assume manual download and placement
echo "Copy the 'pop' binary to $INSTALL_DIR/pop and press Enter to continue."
read

# Set permissions
chmod 755 "$INSTALL_DIR/pop"
chown popcache:popcache "$INSTALL_DIR/pop"

# 3. Configuration
echo "Creating configuration file..."

cat > "$CONFIG_FILE" << EOL
{
  "pop_name": "$POP_NAME",
  "pop_location": "$LOCATION",
  "server": {
    "host": "0.0.0.0",
    "port": 443,
    "http_port": 80,
    "workers": 40
  },
  "cache_config": {
    "memory_cache_size_mb": 4096,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": 100,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "$NODE_NAME",
    "name": "Your Name",
    "email": "$EMAIL",
    "website": "$WEBSITE",
    "discord": "$DISCORD",
    "telegram": "$TELEGRAM",
    "solana_pubkey": "$SOLANA_PUBKEY"
  }
}
EOL

chown popcache:popcache "$CONFIG_FILE"
chmod 644 "$CONFIG_FILE"

# 4. Create Systemd Service
echo "Setting up systemd service..."

cat > /etc/systemd/system/popcache.service << EOL
[Unit]
Description=POP Cache Node
After=network.target

[Service]
Type=simple
User=popcache
Group=popcache
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/pop
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=append:$INSTALL_DIR/logs/stdout.log
StandardError=append:$INSTALL_DIR/logs/stderr.log
Environment=POP_CONFIG_PATH=$INSTALL_DIR/config.json

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable, and start service
systemctl daemon-reload
systemctl enable popcache
systemctl start popcache

# 5. Configure Log Rotation
echo "Configuring log rotation..."

cat > /etc/logrotate.d/popcache << EOL
$INSTALL_DIR/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 popcache popcache
    sharedscripts
    postrotate
        systemctl reload popcache >/dev/null 2>&1 || true
    endscript
}
EOL

# 6. Firewall Configuration
echo "Configuring firewall..."

if command -v ufw >/dev/null; then
  ufw allow 80/tcp
  ufw allow 443/tcp
  echo "UFW rules added for ports 80 and 443."
else
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  echo "iptables rules added for ports 80 and 443."
fi

# 7. Validate Setup
echo "Validating setup..."

# Check service status
systemctl status popcache --no-pager

# Check if ports are listening
netstat -tuln | grep -E ':(80|443)' || echo "Ports 80 or 443 not listening. Check configuration."

# Validate configuration
su - popcache -c "$INSTALL_DIR/pop --validate-config" || {
  echo "Configuration validation failed. Check $CONFIG_FILE."
  exit 1
}

echo "POP Cache Node setup complete!"
echo "Monitor logs with: tail -f $INSTALL_DIR/logs/*.log"
echo "Check service status with: sudo systemctl status popcache"
echo "Check health with: curl http://localhost/health"
