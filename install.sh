#!/bin/bash

# Raspberry Pi Configuration Installation Script
# Author: mnichols08
# Date: August 2025

# Default Configuration
DEFAULT_TEMP_DIR="/var/tmp/raspberry-config"
TEMP_DIR="$DEFAULT_TEMP_DIR"

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
    echo "  --skip-theme            Skip theme installation"
    echo "  --skip-x735             Skip X735 power management installation"
    echo "  --skip-gps              Skip GPS installation"
    echo "  --no-reboot             Don't reboot after installation"
    echo ""
    echo "Examples:"
    echo "  $0                      # Complete setup: init + all components (interactive)"
    echo "  $0 -n                   # Complete setup: init + all components (non-interactive)"
    echo "  $0 --skip-gps           # Setup everything except GPS"
    echo "  $0 --temp-dir /tmp/config # Use custom temporary directory"
    echo ""
    echo "Note: If the configuration directory doesn't exist, the init script will be"
    echo "      run automatically before component installation."
    echo ""
}

# Parse command line arguments
INTERACTIVE=true
INSTALL_THEME=true
INSTALL_X735=true
INSTALL_GPS=true
DO_REBOOT=true

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

# Check if the configuration directory exists, if not run init script
if [ ! -d "$TEMP_DIR" ]; then
    print_warning "Configuration directory not found: $TEMP_DIR"
    print_info "Running initial setup script first..."
    
    # Check if init script exists
    if [ ! -f "init/init.sh" ]; then
        print_error "Init script not found: init/init.sh"
        print_error "Please ensure you are running this script from the project root directory"
        exit 1
    fi
    
    # Run init script with appropriate flags
    if [ "$INTERACTIVE" = false ]; then
        print_info "Running init script in non-interactive mode..."
        sudo bash init/init.sh --non-interactive --temp-dir "$TEMP_DIR"
    else
        print_info "Running init script..."
        sudo bash init/init.sh --temp-dir "$TEMP_DIR"
    fi
    
    init_exit_code=$?
    if [ $init_exit_code -ne 0 ]; then
        print_error "Initial setup failed (exit code: $init_exit_code)"
        exit 1
    fi
    
    print_success "Initial setup completed successfully"
    
    # Verify the temp directory was created
    if [ ! -d "$TEMP_DIR" ]; then
        print_error "Configuration directory still not found after init: $TEMP_DIR"
        exit 1
    fi
fi

# Interactive configuration
if [ "$INTERACTIVE" = true ]; then
    echo ""
    print_info "=== Raspberry Pi Configuration Installation ==="
    echo ""
    print_info "This script will automatically run initial setup if needed, then install:"
    echo "  1. Theme customization (backgrounds, splash screens)"
    echo "  2. X735 power management board support"
    echo "  3. GPS functionality setup"
    echo ""
    
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
