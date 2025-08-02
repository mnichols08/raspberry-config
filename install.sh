#!/bin/bash

# Raspberry Pi Configuration Installation Script
# This script handles the complete setup process:
# 1. Clones/downloads the configuration repository
# 2. Runs initial system setup (init.sh) 
# 3. Installs selected components (theme, X735, GPS)
# 
# Author: mnichols08
# Date: August 2025

# Default Configuration
DEFAULT_TEMP_DIR="/var/tmp/raspberry-config"
DEFAULT_REPO_URL="https://github.com/mnichols08/raspberry-config.git"
TEMP_DIR="$DEFAULT_TEMP_DIR"
REPO_URL="$DEFAULT_REPO_URL"

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

# Function to load configuration from file
load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        print_info "Loading configuration from: $config_file"
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            
            # Remove quotes from value if present
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            # Set temp_dir if found in config
            if [ "$key" = "temp_dir" ] && [ -n "$value" ]; then
                TEMP_DIR="$value"
                print_info "Using temp directory from config: $TEMP_DIR"
            fi
            
            # Set repo_url if found in config
            if [ "$key" = "repo_url" ] && [ -n "$value" ]; then
                REPO_URL="$value"
                print_info "Using repository URL from config: $REPO_URL"
            fi
            
            # Set hostname if found in config
            if [ "$key" = "hostname" ] && [ -n "$value" ] && [ -z "$INIT_HOSTNAME" ]; then
                INIT_HOSTNAME="$value"
                print_info "Using hostname from config: $INIT_HOSTNAME"
            fi
            
            # Set password if found in config
            if [ "$key" = "pi_password" ] && [ -n "$value" ] && [ -z "$INIT_PASSWORD" ]; then
                INIT_PASSWORD="$value"
                print_info "Using password from config: [hidden]"
            fi
            
            # Set WiFi SSID if found in config
            if [ "$key" = "wifi_ssid" ] && [ -n "$value" ] && [ -z "$INIT_WIFI_SSID" ]; then
                INIT_WIFI_SSID="$value"
                print_info "Using WiFi SSID from config: $INIT_WIFI_SSID"
            fi
            
            # Set WiFi key if found in config
            if [ "$key" = "wifi_password" ] && [ -n "$value" ] && [ -z "$INIT_WIFI_KEY" ]; then
                INIT_WIFI_KEY="$value"
                print_info "Using WiFi key from config: [hidden]"
            fi
        done < "$config_file"
    fi
}

# Function to show usage
show_usage() {
    echo "Raspberry Pi Configuration Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script will automatically run the initial setup (init/init.sh) if needed,"
    echo "then install the selected components."
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive    Run in non-interactive mode"
    echo "  -h, --help              Show this help message"
    echo "  --temp-dir DIR          Set temporary directory (default: $DEFAULT_TEMP_DIR)"
    echo "  --repo-url URL          Set repository URL (default: $DEFAULT_REPO_URL)"
    echo "  -c, --config FILE       Load configuration from file"
    echo "  --hostname HOSTNAME     Set hostname for initial setup"
    echo "  --password PASSWORD     Set pi user password for initial setup"
    echo "  --wifi-ssid SSID        Set WiFi SSID for initial setup"
    echo "  --wifi-key KEY          Set WiFi password for initial setup"
    echo "  --skip-theme            Skip theme installation"
    echo "  --skip-x735             Skip X735 power management installation"
    echo "  --skip-gps              Skip GPS installation"
    echo "  --no-reboot             Don't reboot after installation"
    echo ""
    echo "Examples:"
    echo "  $0                      # Complete setup: clone + init + all components (interactive)"
    echo "  $0 -n                   # Complete setup: clone + init + all components (non-interactive)"
    echo "  $0 --skip-gps           # Setup everything except GPS"
    echo "  $0 --temp-dir /tmp/config # Use custom temporary directory"
    echo "  $0 --repo-url https://github.com/user/fork.git # Use forked repository"
    echo "  $0 --hostname MyPi --password secret --wifi-ssid MyNet --wifi-key wifipass -n"
    echo "                          # Non-interactive with custom configuration"
    echo ""
    echo "Note: The script will automatically clone the repository, run initial setup,"
    echo "      and install selected components. Configuration arguments are passed to init script."
    echo ""
}

# Parse command line arguments
INTERACTIVE=true
INSTALL_THEME=true
INSTALL_X735=true
INSTALL_GPS=true
DO_REBOOT=true

# Configuration variables to pass to init script
INIT_HOSTNAME=""
INIT_PASSWORD=""
INIT_WIFI_SSID=""
INIT_WIFI_KEY=""
INIT_CONFIG_FILE=""

# Try to load configuration from default locations
for config_path in "init/pi-config.conf" "/etc/pi-config.conf" "/var/tmp/raspberry-config/init/pi-config.conf"; do
    if [ -f "$config_path" ]; then
        load_config "$config_path"
        break
    fi
done

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
        --temp-dir)
            if [ -n "$2" ]; then
                TEMP_DIR="$2"
                print_info "Using custom temp directory: $TEMP_DIR"
                shift 2
            else
                print_error "--temp-dir requires a directory path"
                exit 1
            fi
            ;;
        --repo-url)
            if [ -n "$2" ]; then
                REPO_URL="$2"
                print_info "Using custom repository URL: $REPO_URL"
                shift 2
            else
                print_error "--repo-url requires a URL"
                exit 1
            fi
            ;;
        -c|--config)
            if [ -n "$2" ]; then
                INIT_CONFIG_FILE="$2"
                print_info "Using config file: $INIT_CONFIG_FILE"
                shift 2
            else
                print_error "--config requires a file path"
                exit 1
            fi
            ;;
        --hostname)
            if [ -n "$2" ]; then
                INIT_HOSTNAME="$2"
                print_info "Using hostname: $INIT_HOSTNAME"
                shift 2
            else
                print_error "--hostname requires a hostname"
                exit 1
            fi
            ;;
        --password)
            if [ -n "$2" ]; then
                INIT_PASSWORD="$2"
                print_info "Using custom password: [hidden]"
                shift 2
            else
                print_error "--password requires a password"
                exit 1
            fi
            ;;
        --wifi-ssid)
            if [ -n "$2" ]; then
                INIT_WIFI_SSID="$2"
                print_info "Using WiFi SSID: $INIT_WIFI_SSID"
                shift 2
            else
                print_error "--wifi-ssid requires an SSID"
                exit 1
            fi
            ;;
        --wifi-key)
            if [ -n "$2" ]; then
                INIT_WIFI_KEY="$2"
                print_info "Using WiFi key: [hidden]"
                shift 2
            else
                print_error "--wifi-key requires a password"
                exit 1
            fi
            ;;
        --skip-theme)
            INSTALL_THEME=false
            shift
            ;;
        --skip-x735)
            INSTALL_X735=false
            shift
            ;;
        --skip-gps)
            INSTALL_GPS=false
            shift
            ;;
        --no-reboot)
            DO_REBOOT=false
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_info "Starting Raspberry Pi configuration installation..."

# Ensure we have git installed
if ! command -v git >/dev/null 2>&1; then
    print_info "Installing git..."
    sudo apt update && sudo apt install -y git
    if [ $? -ne 0 ]; then
        print_error "Failed to install git"
        exit 1
    fi
    print_success "Git installed successfully"
fi

# Create temporary directory
print_info "Creating temporary directory: $TEMP_DIR"
sudo mkdir -p "$TEMP_DIR"
if [ $? -ne 0 ]; then
    print_error "Failed to create temporary directory: $TEMP_DIR"
    exit 1
fi

# Clone or update the repository
print_info "Downloading configuration files from: $REPO_URL"
if [ -d "$TEMP_DIR/.git" ]; then
    print_info "Repository already exists, updating..."
    cd "$TEMP_DIR" && sudo git pull
else
    print_info "Cloning repository..."
    sudo git clone "$REPO_URL" "$TEMP_DIR"
fi

if [ $? -ne 0 ]; then
    print_error "Failed to download configuration files from: $REPO_URL"
    exit 1
fi

print_success "Configuration files downloaded successfully"

# Make scripts executable
print_info "Making scripts executable..."
sudo find "$TEMP_DIR" -name "*.sh" -exec chmod +x {} \;

# Fix hostname resolution issues
fix_hostname_resolution

# Now check if we need to run the init script
if [ ! -f "$TEMP_DIR/init/.init_completed" ]; then
    print_info "Running initial setup script..."
    
    # Build init script arguments
    init_args=""
    
    # Add non-interactive flag if needed
    if [ "$INTERACTIVE" = false ]; then
        init_args="$init_args --non-interactive"
    fi
    
    # Add temp directory
    init_args="$init_args --temp-dir \"$TEMP_DIR\""
    
    # Add configuration file if specified
    if [ -n "$INIT_CONFIG_FILE" ]; then
        init_args="$init_args --config \"$INIT_CONFIG_FILE\""
    fi
    
    # Add hostname if specified
    if [ -n "$INIT_HOSTNAME" ]; then
        init_args="$init_args --hostname \"$INIT_HOSTNAME\""
    fi
    
    # Add password if specified
    if [ -n "$INIT_PASSWORD" ]; then
        init_args="$init_args --password \"$INIT_PASSWORD\""
    fi
    
    # Add WiFi SSID if specified
    if [ -n "$INIT_WIFI_SSID" ]; then
        init_args="$init_args --wifi-ssid \"$INIT_WIFI_SSID\""
    fi
    
    # Add WiFi key if specified
    if [ -n "$INIT_WIFI_KEY" ]; then
        init_args="$init_args --wifi-key \"$INIT_WIFI_KEY\""
    fi
    
    # Run init script with constructed arguments
    print_info "Running init script with arguments: $(echo $init_args | sed 's/--password "[^"]*"/--password [hidden]/g' | sed 's/--wifi-key "[^"]*"/--wifi-key [hidden]/g')"
    eval "sudo bash \"$TEMP_DIR/init/init.sh\" $init_args"
    
    init_exit_code=$?
    if [ $init_exit_code -ne 0 ]; then
        print_error "Initial setup failed (exit code: $init_exit_code)"
        exit 1
    fi
    
    print_success "Initial setup completed successfully"
    
    # Create completion marker
    sudo touch "$TEMP_DIR/init/.init_completed"
else
    print_info "Initial setup already completed, skipping..."
fi

# Interactive configuration
if [ "$INTERACTIVE" = true ]; then
    echo ""
    print_info "=== Raspberry Pi Configuration Installation ==="
    echo ""
    print_info "This script will:"
    print_info "1. Download the latest configuration files from the repository"
    print_info "2. Run initial system setup (hostname, WiFi, password, etc.)"
    print_info "3. Install selected components:"
    echo "     - Theme customization (backgrounds, splash screens)"
    echo "     - X735 power management board support"
    echo "     - GPS functionality setup"
    echo ""
    
    # Show configuration that will be passed to init script if any is set
    if [ -n "$INIT_HOSTNAME" ] || [ -n "$INIT_PASSWORD" ] || [ -n "$INIT_WIFI_SSID" ] || [ -n "$INIT_WIFI_KEY" ] || [ -n "$INIT_CONFIG_FILE" ]; then
        print_info "Configuration for initial setup:"
        [ -n "$INIT_HOSTNAME" ] && echo "  Hostname: $INIT_HOSTNAME"
        [ -n "$INIT_PASSWORD" ] && echo "  Password: [hidden]"
        [ -n "$INIT_WIFI_SSID" ] && echo "  WiFi SSID: $INIT_WIFI_SSID"
        [ -n "$INIT_WIFI_KEY" ] && echo "  WiFi Key: [hidden]"
        [ -n "$INIT_CONFIG_FILE" ] && echo "  Config File: $INIT_CONFIG_FILE"
        echo ""
    fi
    
    if [ "$INSTALL_THEME" = true ]; then
        echo -n "Install theme customization? [Y/n]: "
        read -r confirm_theme
        if [[ "$confirm_theme" =~ ^[Nn]$ ]]; then
            INSTALL_THEME=false
        fi
    fi
    
    if [ "$INSTALL_X735" = true ]; then
        echo -n "Install X735 power management? [Y/n]: "
        read -r confirm_x735
        if [[ "$confirm_x735" =~ ^[Nn]$ ]]; then
            INSTALL_X735=false
        fi
    fi
    
    if [ "$INSTALL_GPS" = true ]; then
        echo -n "Install GPS functionality? [Y/n]: "
        read -r confirm_gps
        if [[ "$confirm_gps" =~ ^[Nn]$ ]]; then
            INSTALL_GPS=false
        fi
    fi
    
    if [ "$DO_REBOOT" = true ]; then
        echo -n "Reboot after installation? [Y/n]: "
        read -r confirm_reboot
        if [[ "$confirm_reboot" =~ ^[Nn]$ ]]; then
            DO_REBOOT=false
        fi
    fi
    
    echo ""
    print_info "Installation Summary:"
    echo "  Theme customization: $([ "$INSTALL_THEME" = true ] && echo "Yes" || echo "No")"
    echo "  X735 power management: $([ "$INSTALL_X735" = true ] && echo "Yes" || echo "No")"
    echo "  GPS functionality: $([ "$INSTALL_GPS" = true ] && echo "Yes" || echo "No")"
    echo "  Reboot after installation: $([ "$DO_REBOOT" = true ] && echo "Yes" || echo "No")"
    echo ""
    
    echo -n "Proceed with installation? [Y/n]: "
    read -r final_confirm
    if [[ "$final_confirm" =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled by user"
        exit 0
    fi
fi

# Function to run installation with error checking
run_installation() {
    local script_path="$1"
    local component_name="$2"
    local non_interactive_flag="$3"
    
    if [ ! -f "$script_path" ]; then
        print_error "Installation script not found: $script_path"
        return 1
    fi
    
    print_info "Installing $component_name..."
    
    if [ "$INTERACTIVE" = false ] && [ -n "$non_interactive_flag" ]; then
        sudo bash "$script_path" "$non_interactive_flag"
    else
        sudo bash "$script_path"
    fi
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "$component_name installed successfully"
        return 0
    else
        print_error "$component_name installation failed (exit code: $exit_code)"
        return 1
    fi
}

# Function to fix hostname resolution
fix_hostname_resolution() {
    local current_hostname=$(hostname)
    print_info "Fixing hostname resolution for: $current_hostname"
    
    # Check if hostname is in /etc/hosts
    if ! grep -q "127.0.1.1.*$current_hostname" /etc/hosts; then
        print_info "Adding hostname to /etc/hosts..."
        
        # Remove any existing 127.0.1.1 entries
        sudo sed -i '/^127.0.1.1/d' /etc/hosts
        
        # Add the current hostname
        echo "127.0.1.1       $current_hostname" | sudo tee -a /etc/hosts > /dev/null
        print_success "Hostname resolution configured"
    else
        print_info "Hostname already configured in /etc/hosts"
    fi
}

# Installation counter
INSTALLED_COUNT=0
FAILED_COUNT=0


# Customize the Theme
if [ "$INSTALL_THEME" = true ]; then
    if run_installation "$TEMP_DIR/theme/install_theme.sh" "Theme customization" "-n"; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

# Install X735 power management
if [ "$INSTALL_X735" = true ]; then
    if run_installation "$TEMP_DIR/x735/x735_install.sh" "X735 power management" "-n"; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

# Install GPS functionality
if [ "$INSTALL_GPS" = true ]; then
    if run_installation "$TEMP_DIR/gps-berry/gpsberry_install.sh" "GPS functionality" ""; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

echo ""
print_info "Installation Summary:"
print_success "Successfully installed: $INSTALLED_COUNT components"
if [ $FAILED_COUNT -gt 0 ]; then
    print_error "Failed installations: $FAILED_COUNT components"
fi

# Clean up the temporary install directory
print_info "Cleaning up temporary directory..."
if [ "$INTERACTIVE" = true ]; then
    echo -n "Remove temporary installation files? [Y/n]: "
    read -r cleanup_confirm
    if [[ ! "$cleanup_confirm" =~ ^[Nn]$ ]]; then
        sudo rm -rf "$TEMP_DIR"
        print_success "Temporary files cleaned up"
    fi
else
    sudo rm -rf "$TEMP_DIR"
    print_success "Temporary files cleaned up"
fi

# Reboot if requested
if [ "$DO_REBOOT" = true ]; then
    echo ""
    print_info "Installation completed. The system will reboot in 10 seconds..."
    print_info "Press Ctrl+C to cancel reboot"
    
    for i in {10..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
    
    print_info "Rebooting now..."
    sudo reboot
else
    echo ""
    print_success "Installation completed successfully!"
    print_info "You may need to reboot for all changes to take effect"
fi
