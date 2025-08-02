#!/bin/bash

# Raspberry Pi Initial Setup Script
# Designed for fresh Raspbian Buster installations
# Author: Mikey Nichols

# Default values (can be overridden by environment variables)
DEFAULT_HOSTNAME="Pi"
DEFAULT_PASSWORD="${PI_PASSWORD:-raspberry}"
DEFAULT_WIFI_SSID="${WIFI_SSID:-HomeNetwork}"
DEFAULT_WIFI_KEY="${WIFI_PASSWORD:-magicallake223}"
DEFAULT_REPO_URL="${REPO_URL:-https://github.com/mnichols08/raspberry-config.git}"
DEFAULT_TEMP_DIR="${TEMP_DIR:-/var/tmp/raspberry-config}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "Raspberry Pi Initial Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive    Run in non-interactive mode with defaults"
    echo "  -c, --config FILE        Load configuration from file"
    echo "  -h, --help              Show this help message"
    echo "  --hostname HOSTNAME     Set hostname (default: $DEFAULT_HOSTNAME)"
    echo "  --password PASSWORD     Set pi user password (default: from PI_PASSWORD env var or $DEFAULT_PASSWORD)"
    echo "  --wifi-ssid SSID        Set WiFi SSID (default: from WIFI_SSID env var or $DEFAULT_WIFI_SSID)"
    echo "  --wifi-key KEY          Set WiFi key (default: from WIFI_PASSWORD env var or [hidden])"
    echo "  --repo-url URL          Set repository URL (default: from REPO_URL env var or $DEFAULT_REPO_URL)"
    echo "  --temp-dir DIR          Set temporary directory (default: from TEMP_DIR env var or $DEFAULT_TEMP_DIR)"
    echo ""
    echo "Environment Variables (for sensitive data):"
    echo "  PI_PASSWORD             Pi user password"
    echo "  WIFI_SSID               WiFi network name"
    echo "  WIFI_PASSWORD           WiFi password/key"
    echo "  REPO_URL                Configuration repository URL"
    echo "  TEMP_DIR                Temporary directory for installation files"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 -n                                 # Non-interactive with defaults"
    echo "  $0 --hostname MyPi --password MyPass  # Set hostname and password via args"
    echo "  PI_PASSWORD=secret WIFI_SSID=MyNet WIFI_PASSWORD=secret $0 -n  # Use env vars"
    echo ""
    echo "Security Note:"
    echo "  Use environment variables for sensitive data like passwords to avoid"
    echo "  exposing them in command history or process lists."
    echo ""
}

# Function to validate input
validate_hostname() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9-]{1,63}$ ]]; then
        print_error "Invalid hostname. Use only letters, numbers, and hyphens (max 63 chars)"
        return 1
    fi
    return 0
}

validate_wifi_ssid() {
    if [[ ${#1} -eq 0 || ${#1} -gt 32 ]]; then
        print_error "WiFi SSID must be 1-32 characters"
        return 1
    fi
    return 0
}

# Function to load configuration from file
load_config_file() {
    local config_file="$1"
    
    if [ -f "$config_file" ]; then
        print_info "Loading configuration from: $config_file"
        
        # Source the config file in a safe way
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes from value if present
            value=$(echo "$value" | sed 's/^["'\'']\|["'\'']$//g')
            
            case $key in
                PI_PASSWORD|pi_password)
                    export PI_PASSWORD="$value"
                    ;;
                WIFI_SSID|wifi_ssid)
                    export WIFI_SSID="$value"
                    ;;
                WIFI_PASSWORD|wifi_password)
                    export WIFI_PASSWORD="$value"
                    ;;
                REPO_URL|repo_url)
                    export REPO_URL="$value"
                    ;;
                HOSTNAME|hostname)
                    export PI_HOSTNAME="$value"
                    ;;
                TEMP_DIR|temp_dir)
                    export TEMP_DIR="$value"
                    ;;
            esac
        done < "$config_file"
        
        print_success "Configuration loaded successfully"
    fi
}

# Parse command line arguments
INTERACTIVE=true
HOSTNAME=""
PASSWORD=""
WIFI_SSID=""
WIFI_KEY=""
REPO_URL=""
TEMP_DIR=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --wifi-ssid)
            WIFI_SSID="$2"
            shift 2
            ;;
        --wifi-key)
            WIFI_KEY="$2"
            shift 2
            ;;
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --temp-dir)
            TEMP_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Load configuration file if specified
if [ -n "$CONFIG_FILE" ]; then
    load_config_file "$CONFIG_FILE"
fi

# Set defaults if not provided (environment variables take precedence over defaults)
HOSTNAME=${HOSTNAME:-${PI_HOSTNAME:-$DEFAULT_HOSTNAME}}
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
WIFI_SSID=${WIFI_SSID:-$DEFAULT_WIFI_SSID}
WIFI_KEY=${WIFI_KEY:-$DEFAULT_WIFI_KEY}
REPO_URL=${REPO_URL:-$DEFAULT_REPO_URL}
TEMP_DIR=${TEMP_DIR:-$DEFAULT_TEMP_DIR}

print_info "Starting Raspberry Pi initial setup..."

# Interactive configuration
if [ "$INTERACTIVE" = true ]; then
    echo ""
    print_info "=== Raspberry Pi Initial Setup Configuration ==="
    echo ""
    
    # Hostname configuration
    echo -n "Enter hostname (current: $HOSTNAME): "
    read -r input_hostname
    if [ -n "$input_hostname" ]; then
        if validate_hostname "$input_hostname"; then
            HOSTNAME="$input_hostname"
        else
            print_warning "Using default hostname: $HOSTNAME"
        fi
    fi
    
    # Password configuration
    echo -n "Enter new password for pi user (current: [hidden]): "
    read -r input_password
    if [ -n "$input_password" ]; then
        PASSWORD="$input_password"
    fi
    
    # WiFi configuration
    echo -n "Enter WiFi SSID (current: $WIFI_SSID): "
    read -r input_wifi_ssid
    if [ -n "$input_wifi_ssid" ]; then
        if validate_wifi_ssid "$input_wifi_ssid"; then
            WIFI_SSID="$input_wifi_ssid"
        else
            print_warning "Using default WiFi SSID: $WIFI_SSID"
        fi
    fi
    
    echo -n "Enter WiFi key (current: [hidden]): "
    read -r input_wifi_key
    if [ -n "$input_wifi_key" ]; then
        WIFI_KEY="$input_wifi_key"
    fi
    
    # Repository URL
    echo -n "Enter repository URL (current: $REPO_URL): "
    read -r input_repo_url
    if [ -n "$input_repo_url" ]; then
        REPO_URL="$input_repo_url"
    fi
    
    # Temporary Directory
    echo -n "Enter temporary directory (current: $TEMP_DIR): "
    read -r input_temp_dir
    if [ -n "$input_temp_dir" ]; then
        TEMP_DIR="$input_temp_dir"
    fi
    
    echo ""
    print_info "Configuration Summary:"
    echo "  Hostname: $HOSTNAME"
    echo "  Password: [hidden]"
    echo "  WiFi SSID: $WIFI_SSID"
    echo "  WiFi Key: [hidden]"
    echo "  Repository: $REPO_URL"
    echo "  Temp Directory: $TEMP_DIR"
    echo ""
    
    echo -n "Proceed with configuration? [Y/n]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "This script should not be run as root. Run as pi user with sudo when needed."
    exit 1
fi

# Update system packages first
print_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    print_success "System packages updated successfully"
else
    print_error "Failed to update system packages"
    exit 1
fi

# Set up the hostname
print_info "Setting hostname to: $HOSTNAME"
sudo hostnamectl set-hostname "$HOSTNAME"
if [ $? -eq 0 ]; then
    print_success "Hostname set to: $HOSTNAME"
else
    print_error "Failed to set hostname"
    exit 1
fi

# Change the default password for the pi user
print_info "Changing password for pi user..."
echo "pi:$PASSWORD" | sudo chpasswd
if [ $? -eq 0 ]; then
    print_success "Password changed successfully"
else
    print_error "Failed to change password"
    exit 1
fi

# Configure WiFi
print_info "Configuring WiFi connection..."
print_info "SSID: $WIFI_SSID"

# Check if wlan0 interface exists
if ! ip link show wlan0 >/dev/null 2>&1; then
    print_error "WiFi interface wlan0 not found"
    exit 1
fi

# Configure WiFi using iwconfig (for WEP) or wpa_supplicant (for WPA/WPA2)
# First, try to determine if it's WEP or WPA by key length/format
if [[ ${#WIFI_KEY} -eq 10 || ${#WIFI_KEY} -eq 26 ]] && [[ "$WIFI_KEY" =~ ^[0-9A-Fa-f]+$ ]]; then
    # Looks like WEP hex key
    print_info "Configuring WEP WiFi connection..."
    sudo iwconfig wlan0 essid "$WIFI_SSID" key "$WIFI_KEY"
else
    # Assume WPA/WPA2
    print_info "Configuring WPA/WPA2 WiFi connection..."
    
    # Create wpa_supplicant configuration
    sudo tee /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null <<EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_KEY"
}
EOF
    
    # Restart wpa_supplicant
    sudo systemctl restart wpa_supplicant
    sudo wpa_cli -i wlan0 reconfigure
fi

# Wait for the network to connect
print_info "Waiting for network connection..."
for i in {1..30}; do
    sleep 1
    if ping -c1 8.8.8.8 >/dev/null 2>&1; then
        break
    fi
    echo -n "."
done
echo ""

# Check the network connection
print_info "Checking network connection..."
if command -v ifconfig >/dev/null 2>&1; then
    ifconfig wlan0 | grep -E "inet [0-9]"
else
    ip addr show wlan0 | grep -E "inet [0-9]"
fi

# Get the IP address if connection is established
ip_address=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
if [ -n "$ip_address" ]; then
    print_success "Pi IP address: $ip_address"
    print_success "Network connection established"
else
    print_warning "No network connection found"
    print_warning "You may need to configure WiFi manually"
fi

# Install git if not present
if ! command -v git >/dev/null 2>&1; then
    print_info "Installing git..."
    sudo apt install -y git
    if [ $? -eq 0 ]; then
        print_success "Git installed successfully"
    else
        print_error "Failed to install git"
        exit 1
    fi
fi

# Create a temporary directory for the installation files
print_info "Creating temporary directory: $TEMP_DIR"
sudo mkdir -p "$TEMP_DIR"
if [ $? -eq 0 ]; then
    print_success "Temporary directory created"
else
    print_error "Failed to create temporary directory"
    exit 1
fi

# Download the configuration repository
print_info "Downloading configuration files from: $REPO_URL"
if [ -d "$TEMP_DIR/.git" ]; then
    print_info "Repository already exists, updating..."
    cd "$TEMP_DIR" && sudo git pull
else
    sudo git clone "$REPO_URL" "$TEMP_DIR"
fi

if [ $? -eq 0 ]; then
    print_success "Configuration files downloaded successfully"
else
    print_error "Failed to download configuration files"
    exit 1
fi

# Make scripts executable
print_info "Making scripts executable..."
sudo find "$TEMP_DIR" -name "*.sh" -exec chmod +x {} \;

print_success "Initial setup completed successfully!"
echo ""
print_info "Next steps:"
print_info "1. Run the main installation script: sudo bash $TEMP_DIR/install.sh"
print_info "2. Or run individual component scripts as needed"
print_info ""
print_info "Available components:"
print_info "- Theme installation: sudo bash $TEMP_DIR/theme/install_theme.sh"
print_info "- X735 power management: sudo bash $TEMP_DIR/x735/x735_install.sh"
print_info "- GPS setup: sudo bash $TEMP_DIR/gps-berry/gpsberry_install.sh"
echo ""