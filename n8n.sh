#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Functions
error_exit() {
	echo -e "\n${RED}❌ Error: $1${RESET}" >&2
	exit 1
}

info() {
	echo -e "${CYAN}ℹ️  $1${RESET}"
}

success() {
	echo -e "${GREEN}✅ $1${RESET}"
}

line() {
	echo -e "${BLUE}───────────────────────────────────────────${RESET}"
}

# Show menu
show_menu() {
    clear
    echo -e "${CYAN}By --> Peyman * Github.com/Ptechgithub * ${RESET}"
    echo ""
	echo -e "${YELLOW}╔══════════════════════════════════════════╗${RESET}"
	echo -e "${YELLOW}║${CYAN}            n8n Installer Menu            ${YELLOW}║${RESET}"
	echo -e "${YELLOW}╠══════════════════════════════════════════╣"
	echo -e "${YELLOW}║ 1️⃣  Install n8n                          ║${RESET}"
	echo -e "${YELLOW}║ 2️⃣  Uninstall n8n                        ║${RESET}"
	echo -e "${YELLOW}║ 3️⃣  Update n8n (Pull latest stable)      ║${RESET}"
	echo -e "${YELLOW}║ 4️⃣  Setup Automatic Updates (Cron)       ║${RESET}"
	echo -e "${YELLOW}║ 5️⃣  Exit                                 ║${RESET}"
	echo -e "${YELLOW}╚══════════════════════════════════════════╝${RESET}"
	echo
	read -p "📌 Select an option [1-5]: " OPTION
}

# Install n8n
install_n8n() {
	if [ -d "n8n-docker" ]; then
		line
		success "n8n appears to be already installed. Skipping installation."
		return
	fi
	# Check root
	if [ "$EUID" -ne 0 ]; then
		error_exit "Please run this script as root ⚠️"
	fi

	# Install Docker if missing
	if ! command -v docker &>/dev/null; then
		info "Docker not found. Installing Docker 🐳..."
		curl -fsSL https://get.docker.com -o get-docker.sh || error_exit "Failed to download Docker install script."
		sh get-docker.sh || error_exit "Docker installation failed."
		rm get-docker.sh
	else
		line
		success "Docker is already installed 🐳"
	fi

	# Install Docker Compose
	if ! command -v docker-compose &>/dev/null; then
		info "Docker Compose not found. Installing Docker Compose 🔧..."
		LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
		curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Failed to download Docker Compose."
		chmod +x /usr/local/bin/docker-compose
	else
		success "Docker Compose is already installed 🔧"
	fi

	# Inputs
	line
	echo "        🌍 n8n Auto Deployment Setup"
	echo ""
	read -p "🌐 Enter your domain name (leave blank to use server IP): " DOMAIN

	if [ -n "$DOMAIN" ]; then
		read -p "📧 Enter your email address for SSL: " EMAIL
		[ -z "$EMAIL" ] && error_exit "Email is required for SSL"
	fi

	read -p "👤 n8n username (default: admin): " N8N_USER
	N8N_USER=${N8N_USER:-admin}

	read -s -p "🔒 n8n password (default: securepassword): " N8N_PASS
	echo
	N8N_PASS=${N8N_PASS:-securepassword}
	line

	# Setup vars
	if [ -n "$DOMAIN" ]; then
		N8N_HOST="$DOMAIN"
		N8N_PORT=443
		N8N_PROTOCOL="https"
		WEBHOOK_URL="https://$DOMAIN/"
		N8N_SECURE_COOKIE=true
		USE_DOMAIN=true
	else
		SERVER_IP=$(hostname -I | awk '{print $1}')
		N8N_HOST="$SERVER_IP"
		N8N_PORT=5678
		N8N_PROTOCOL="http"
		WEBHOOK_URL="http://$SERVER_IP:5678/"
		N8N_SECURE_COOKIE=false
		USE_DOMAIN=false
	fi

	PROJECT_DIR="n8n-docker"
	mkdir -p "$PROJECT_DIR"
	cd "$PROJECT_DIR" || error_exit "Failed to enter directory"

	# Generate docker-compose.yml
	if [ "$USE_DOMAIN" = true ]; then
		mkdir -p letsencrypt
		touch letsencrypt/acme.json
		chmod 600 letsencrypt/acme.json
		cat >docker-compose.yml <<EOF
version: '3.8'
services:
  traefik:
    image: traefik:latest
    restart: always
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./letsencrypt:/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    networks:
      - web

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: unless-stopped
    environment:
      N8N_HOST: "${N8N_HOST}"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "https"
      N8N_BASIC_AUTH_USER: "${N8N_USER}"
      N8N_BASIC_AUTH_PASSWORD: "${N8N_PASS}"
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_SECURE_COOKIE: "true"
      N8N_USER_MANAGEMENT_DISABLED: "false"
      WEBHOOK_URL: "https://${N8N_HOST}/"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`${N8N_HOST}\`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - web

volumes:
  n8n_data:

networks:
  web:
EOF
	else
		cat >docker-compose.yml <<EOF
version: '3.8'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      N8N_HOST: "${N8N_HOST}"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "http"
      N8N_BASIC_AUTH_USER: "${N8N_USER}"
      N8N_BASIC_AUTH_PASSWORD: "${N8N_PASS}"
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_SECURE_COOKIE: "false"
      N8N_USER_MANAGEMENT_DISABLED: "false"
      WEBHOOK_URL: "http://${N8N_HOST}:5678/"
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOF
	fi

	docker-compose up -d || error_exit "Docker Compose failed"
	line
	success "n8n is running at: $WEBHOOK_URL"
	line
}

# Uninstall n8n
uninstall_n8n() {
	line
	echo -e "⚠️  This will stop and remove n8n containers and data!"
	read -p "Are you sure? (yes/no): " confirm
	if [[ "$confirm" != "yes" ]]; then
		line
		echo "❌ Uninstall cancelled."
		return
	fi

	# Check Docker presence
	if command -v docker &>/dev/null; then
		if docker ps -a --format '{{.Names}}' | grep -q '^n8n$'; then
			info "Stopping and removing n8n container..."
			docker stop n8n &>/dev/null
			docker rm n8n &>/dev/null
		fi
	else
		info "Docker is not installed. Skipping container cleanup."
	fi

	if [ -d "n8n-docker" ]; then
		cd n8n-docker
		if command -v docker-compose &>/dev/null; then
			docker-compose down -v || error_exit "Failed to stop services"
		else
			info "docker-compose not found. Skipping docker-compose cleanup."
		fi
		cd ..
		rm -rf n8n-docker
		line
		success "n8n has been uninstalled and removed from your system."
	else
		line
		info "No installation directory found, but attempted to clean containers."
		success "n8n cleanup complete (if it was installed)."
	fi
}

# Update n8n
update_n8n() {
	if [ ! -d "n8n-docker" ]; then
		line
		error_exit "n8n is not installed. Please install it first."
	fi

	line
	info "Updating n8n to the latest stable version... 🔄"

	cd n8n-docker || error_exit "Failed to enter n8n-docker directory."

	if ! command -v docker-compose &>/dev/null; then
		error_exit "Docker Compose is required for update. Please install it."
	fi

	# Pull all images
	docker-compose pull || error_exit "Failed to pull images."

	# Restart services to apply the update
	docker-compose up -d || error_exit "Failed to restart services after update."

	line
	success "n8n has been updated to the latest stable version! 🚀"
	line
}

# Setup Automatic Updates with Cron
setup_cron_update() {
	if [ ! -d "n8n-docker" ]; then
		line
		error_exit "n8n is not installed. Please install it first."
	fi

	if [ "$EUID" -ne 0 ]; then
		error_exit "Please run this script as root to manage cron jobs ⚠️"
	fi

	line
	info "Setting up automatic n8n updates with cron... ⏰"

	# Get absolute path to installation directory
	INSTALL_DIR=$(realpath n8n-docker)

	# Check if cron job already exists for this directory
	if crontab -l 2>/dev/null | grep -q "$INSTALL_DIR.*docker-compose pull"; then
		line
		success "Automatic update cron job is already set up. Skipping."
		return
	fi

	# Ask for schedule (default: weekly on Sunday at 2 AM)
	echo "Select update frequency:"
	echo "1. Daily (at 2 AM)"
	echo "2. Weekly (Sunday at 2 AM)"
	echo "3. Monthly (1st day at 2 AM)"
	read -p "Enter choice [1-3, default 2]: " FREQ_CHOICE
	FREQ_CHOICE=${FREQ_CHOICE:-2}

	case $FREQ_CHOICE in
		1)
			CRON_SCHEDULE="0 2 * * *"
			;;
		2)
			CRON_SCHEDULE="0 2 * * 0"
			;;
		3)
			CRON_SCHEDULE="0 2 1 * *"
			;;
		*)
			CRON_SCHEDULE="0 2 * * 0"
			;;
	esac

	# Create the cron job entry
	CRON_JOB="$CRON_SCHEDULE cd $INSTALL_DIR && docker-compose pull && docker-compose up -d > /dev/null 2>&1"

	# Add to crontab
	(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - || error_exit "Failed to update crontab."

	line
	success "Automatic update cron job set up successfully!"
	echo -e "${CYAN}Schedule: $CRON_SCHEDULE (n8n-docker update in $INSTALL_DIR)${RESET}"
	info "To view cron jobs: crontab -l"
	info "To remove: crontab -e and delete the line"
	line
}

# Main loop
while true; do
	show_menu
	case "$OPTION" in
	1) install_n8n ;;
	2) uninstall_n8n ;;
	3) update_n8n ;;
	4) setup_cron_update ;;
	5)
		echo "👋 Goodbye!"
		exit 0
		;;
	*) echo "❗ Invalid option. Please select 1, 2, 3, 4, or 5." ;;
	esac
done
