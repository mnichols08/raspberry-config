#!/bin/bash

# Raspberry Pi Essentials Setup Script
# This script handles the essential setup tasks:
# 1. Helps user create pi-config.conf file
# 2. Sets up basic system requirements
# 3. Prepares the system for main installation
# 
# Author: mnichols08
# Date: August 2025

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

# Default values
DEFAULT_CONFIG_DIR="/etc"
DEFAULT_CONFIG_FILE="pi-config.conf"
INTERACTIVE=true

# Function to show usage
show_usage() {
    echo "Raspberry Pi Essentials Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script helps set up essential configuration before running the main installer."
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive    Run in non-interactive mode (uses defaults)"
    echo "  -h, --help              Show this help message"
    echo "  --config-dir DIR        Set configuration directory (default: $DEFAULT_CONFIG_DIR)"
    echo "  --config-file FILE      Set configuration filename (default: $DEFAULT_CONFIG_FILE)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Interactive setup"
    echo "  $0 -n                   # Non-interactive with defaults"
    echo "  $0 --config-dir /home/pi # Place config in user directory"
    echo ""
}

# Parse command line arguments
CONFIG_DIR="$DEFAULT_CONFIG_DIR"
CONFIG_FILE="$DEFAULT_CONFIG_FILE"

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
        --config-dir)
            if [ -n "$2" ]; then
                CONFIG_DIR="$2"
                shift 2
            else
                print_error "--config-dir requires a directory path"
                exit 1
            fi
            ;;
        --config-file)
            if [ -n "$2" ]; then
                CONFIG_FILE="$2"
                shift 2
            else
                print_error "--config-file requires a filename"
                exit 1
            fi
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

CONFIG_PATH="$CONFIG_DIR/$CONFIG_FILE"

print_info "Starting Raspberry Pi essentials setup..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

# Function to install essential packages
install_essentials() {
    print_info "Installing essential packages..."
    
    # Update package lists
    print_info "Updating package lists..."
    apt update
    if [ $? -ne 0 ]; then
        print_error "Failed to update package lists"
        return 1
    fi
    
    # Install essential packages
    local packages="git curl wget nano vim htop"
    print_info "Installing packages: $packages"
    apt install -y $packages
    if [ $? -ne 0 ]; then
        print_error "Failed to install essential packages"
        return 1
    fi
    
    print_success "Essential packages installed successfully"
    return 0
}

# Function to create configuration file
create_config_file() {
    print_info "Creating configuration file: $CONFIG_PATH"
    
    # Default values for configuration
    local hostname_default="raspberrypi"
    local temp_dir_default="/var/tmp/raspberry-config"
    local repo_url_default="https://github.com/mnichols08/raspberry-config.git"
    
    # Get current hostname as default
    if command -v hostname >/dev/null 2>&1; then
        hostname_default=$(hostname)
    fi
    
    # Interactive configuration
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        print_info "=== Configuration Setup ==="
        echo ""
        print_info "Please provide the following configuration options:"
        echo ""
        
        # Hostname
        echo -n "Hostname [$hostname_default]: "
        read -r user_hostname
        [ -z "$user_hostname" ] && user_hostname="$hostname_default"
        
        # Password
        echo -n "Pi user password (leave empty to skip): "
        read -rs user_password
        echo ""
        
        # WiFi SSID
        echo -n "WiFi SSID (leave empty to skip): "
        read -r user_wifi_ssid
        
        # WiFi Password
        if [ -n "$user_wifi_ssid" ]; then
            echo -n "WiFi password: "
            read -rs user_wifi_password
            echo ""
        fi
        
        # Temp directory
        echo -n "Temporary directory [$temp_dir_default]: "
        read -r user_temp_dir
        [ -z "$user_temp_dir" ] && user_temp_dir="$temp_dir_default"
        
        # Repository URL
        echo -n "Repository URL [$repo_url_default]: "
        read -r user_repo_url
        [ -z "$user_repo_url" ] && user_repo_url="$repo_url_default"
        
    else
        # Non-interactive mode - use defaults
        user_hostname="$hostname_default"
        user_password=""
        user_wifi_ssid=""
        user_wifi_password=""
        user_temp_dir="$temp_dir_default"
        user_repo_url="$repo_url_default"
    fi
    
    # Create configuration directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"
    
    # Create configuration file
    cat > "$CONFIG_PATH" << EOF
# Raspberry Pi Configuration File
# Generated by essentials setup on $(date)

# System Configuration
hostname=$user_hostname
$([ -n "$user_password" ] && echo "pi_password=$user_password")

# Network Configuration
$([ -n "$user_wifi_ssid" ] && echo "wifi_ssid=$user_wifi_ssid")
$([ -n "$user_wifi_password" ] && echo "wifi_password=$user_wifi_password")

# Installation Configuration
temp_dir=$user_temp_dir
repo_url=$user_repo_url

# Component Installation (true/false)
install_theme=true
install_x735=true
install_gps=true

# Installation Behavior
interactive_mode=true
auto_reboot=true
cleanup_temp=true
EOF

    if [ $? -eq 0 ]; then
        print_success "Configuration file created: $CONFIG_PATH"
        
        # Set appropriate permissions
        chmod 600 "$CONFIG_PATH"
        print_info "Configuration file permissions set to 600 (owner read/write only)"
        
        # Show configuration (hide sensitive data)
        echo ""
        print_info "Configuration summary:"
        echo "  Hostname: $user_hostname"
        [ -n "$user_password" ] && echo "  Password: [configured]" || echo "  Password: [not configured]"
        [ -n "$user_wifi_ssid" ] && echo "  WiFi SSID: $user_wifi_ssid" || echo "  WiFi: [not configured]"
        [ -n "$user_wifi_password" ] && echo "  WiFi Password: [configured]" || echo "  WiFi Password: [not configured]"
        echo "  Temp Directory: $user_temp_dir"
        echo "  Repository URL: $user_repo_url"
        echo "  Config File: $CONFIG_PATH"
        
        return 0
    else
        print_error "Failed to create configuration file"
        return 1
    fi
}

# Function to set up git configuration
setup_git_config() {
    print_info "Setting up git configuration..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is not installed"
        return 1
    fi
    
    # Set safe directory for git operations
    git config --global --add safe.directory '*'
    
    # Basic git configuration if not already set
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "Raspberry Pi User"
        print_info "Set git user.name to 'Raspberry Pi User'"
    fi
    
    if [ -z "$(git config --global user.email)" ]; then
        git config --global user.email "pi@raspberrypi.local"
        print_info "Set git user.email to 'pi@raspberrypi.local'"
    fi
    
    print_success "Git configuration completed"
    return 0
}

# Function to create essential directories
create_directories() {
    print_info "Creating essential directories..."
    
    # Read temp_dir from config if it exists
    local temp_dir="/var/tmp/raspberry-config"
    if [ -f "$CONFIG_PATH" ]; then
        temp_dir=$(grep "^temp_dir=" "$CONFIG_PATH" | cut -d'=' -f2)
    fi
    
    # Create temp directory
    mkdir -p "$temp_dir"
    if [ $? -eq 0 ]; then
        print_success "Created directory: $temp_dir"
    else
        print_error "Failed to create directory: $temp_dir"
        return 1
    fi
    
    # Create logs directory
    mkdir -p /var/log/raspberry-config
    if [ $? -eq 0 ]; then
        print_success "Created logs directory: /var/log/raspberry-config"
    else
        print_warning "Failed to create logs directory: /var/log/raspberry-config"
    fi
    
    return 0
}

# Main execution
print_info "=== Raspberry Pi Essentials Setup ==="
echo ""

# Check if configuration file already exists
if [ -f "$CONFIG_PATH" ]; then
    if [ "$INTERACTIVE" = true ]; then
        print_warning "Configuration file already exists: $CONFIG_PATH"
        echo -n "Do you want to recreate it? [y/N]: "
        read -r recreate_config
        if [[ ! "$recreate_config" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing configuration file"
        else
            create_config_file
        fi
    else
        print_info "Configuration file already exists, skipping creation"
    fi
else
    create_config_file
fi

# Install essential packages
install_essentials

# Set up git configuration
setup_git_config

# Create essential directories
create_directories

echo ""
print_success "Essentials setup completed successfully!"
echo ""
print_info "Next steps:"
print_info "1. Review your configuration file: $CONFIG_PATH"
print_info "2. Run the main installer: ./install.sh"
print_info "3. Or run specific component installers as needed"
echo ""
