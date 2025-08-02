#!/bin/bash

# Raspberry Pi Configuration Installation Script
# This script handles the complete setup process:
# 1. Runs essentials setup if needed
# 2. Clones/downloads the configuration repository
# 3. Runs initial system setup (init.sh) 
# 4. Installs selected components (theme, X735, GPS)
# 
# Author: mnichols08
# Date: August 2025

# Get script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions if available
if [ -f "$SCRIPT_DIR/essentials/utils.sh" ]; then
    source "$SCRIPT_DIR/essentials/utils.sh"
else
    # Fallback color definitions if utils not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
    print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fi

# Default Configuration
DEFAULT_TEMP_DIR="/var/tmp/raspberry-config"
DEFAULT_REPO_URL="https://github.com/mnichols08/raspberry-config.git"
DEFAULT_CONFIG_FILE="/etc/pi-config.conf"

# Configuration variables
TEMP_DIR="$DEFAULT_TEMP_DIR"
REPO_URL="$DEFAULT_REPO_URL"
CONFIG_FILE="$DEFAULT_CONFIG_FILE"

# Installation flags
INTERACTIVE=true
INSTALL_THEME=true
INSTALL_X735=true
INSTALL_GPS=true
DO_REBOOT=true
RUN_ESSENTIALS=false

# Function to show usage
show_usage() {
    echo "Raspberry Pi Configuration Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script will automatically set up essentials, clone the repository,"
    echo "run initial setup, and install selected components."
    echo ""
    echo "Options:"
    echo "  -n, --non-interactive    Run in non-interactive mode"
    echo "  -h, --help              Show this help message"
    echo "  --temp-dir DIR          Set temporary directory (default: $DEFAULT_TEMP_DIR)"
    echo "  --repo-url URL          Set repository URL (default: $DEFAULT_REPO_URL)"
    echo "  --config FILE           Use specific configuration file (default: $DEFAULT_CONFIG_FILE)"
    echo "  --essentials            Run essentials setup first"
    echo "  --skip-theme            Skip theme installation"
    echo "  --skip-x735             Skip X735 power management installation"
    echo "  --skip-gps              Skip GPS installation"
    echo "  --no-reboot             Don't reboot after installation"
    echo "  --force-fresh           Force fresh clone (remove existing temp directory)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Complete setup with configuration file"
    echo "  $0 --essentials -n      # Run essentials setup first, then non-interactive install"
    echo "  $0 --skip-gps           # Setup everything except GPS"
    echo "  $0 --force-fresh        # Force fresh clone of repository"
    echo ""
    echo "Note: Run with --essentials first if you haven't set up pi-config.conf yet."
    echo ""
}

# Parse command line arguments
FORCE_FRESH=false

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
                shift 2
            else
                print_error "--temp-dir requires a directory path"
                exit 1
            fi
            ;;
        --repo-url)
            if [ -n "$2" ]; then
                REPO_URL="$2"
                shift 2
            else
                print_error "--repo-url requires a URL"
                exit 1
            fi
            ;;
        --config)
            if [ -n "$2" ]; then
                CONFIG_FILE="$2"
                shift 2
            else
                print_error "--config requires a file path"
                exit 1
            fi
            ;;
        --essentials)
            RUN_ESSENTIALS=true
            shift
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
        --force-fresh)
            FORCE_FRESH=true
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

# Check permissions
if ! check_permissions 2>/dev/null; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

# Run essentials setup if requested or if config file doesn't exist
if [ "$RUN_ESSENTIALS" = true ] || [ ! -f "$CONFIG_FILE" ]; then
    if [ "$RUN_ESSENTIALS" = true ]; then
        print_info "Running essentials setup as requested..."
    else
        print_info "Configuration file not found, running essentials setup..."
    fi
    
    # Look for essentials script
    essentials_script=""
    if [ -f "$SCRIPT_DIR/essentials/install_essentials.sh" ]; then
        essentials_script="$SCRIPT_DIR/essentials/install_essentials.sh"
    elif [ -f "$TEMP_DIR/essentials/install_essentials.sh" ]; then
        essentials_script="$TEMP_DIR/essentials/install_essentials.sh"
    else
        print_error "Essentials setup script not found. Please run from the correct directory or clone the repository first."
        exit 1
    fi
    
    # Run essentials setup
    essentials_args=""
    [ "$INTERACTIVE" = false ] && essentials_args="--non-interactive"
    
    bash "$essentials_script" $essentials_args
    if [ $? -ne 0 ]; then
        print_error "Essentials setup failed"
        exit 1
    fi
    
    print_success "Essentials setup completed"
fi

# Load configuration from file
load_config "$CONFIG_FILE" 2>/dev/null

# Override with configuration file values if they exist
[ -n "$CONFIG_temp_dir" ] && TEMP_DIR="$CONFIG_temp_dir"
[ -n "$CONFIG_repo_url" ] && REPO_URL="$CONFIG_repo_url"
[ -n "$CONFIG_install_theme" ] && INSTALL_THEME="$CONFIG_install_theme"
[ -n "$CONFIG_install_x735" ] && INSTALL_X735="$CONFIG_install_x735"
[ -n "$CONFIG_install_gps" ] && INSTALL_GPS="$CONFIG_install_gps"
[ -n "$CONFIG_interactive_mode" ] && INTERACTIVE="$CONFIG_interactive_mode"
[ -n "$CONFIG_auto_reboot" ] && DO_REBOOT="$CONFIG_auto_reboot"

print_info "Using configuration:"
print_info "  Temp directory: $TEMP_DIR"
print_info "  Repository URL: $REPO_URL"
print_info "  Interactive mode: $INTERACTIVE"

# Ensure git is installed
if ! command -v git >/dev/null 2>&1; then
    print_info "Installing git..."
    install_packages git
    if [ $? -ne 0 ]; then
        print_error "Failed to install git"
        exit 1
    fi
fi

# Clone or update repository
clone_or_update_repo "$REPO_URL" "$TEMP_DIR" "$FORCE_FRESH"
if [ $? -ne 0 ]; then
    print_error "Failed to clone/update repository"
    exit 1
fi

# Source utils from the downloaded repository if we didn't have it before
if [ -f "$TEMP_DIR/essentials/utils.sh" ] && [ ! -f "$SCRIPT_DIR/essentials/utils.sh" ]; then
    source "$TEMP_DIR/essentials/utils.sh"
fi

# Fix hostname resolution
fix_hostname_resolution

# Check if we need to run the init script
if [ ! -f "$TEMP_DIR/init/.init_completed" ]; then
    print_info "Running initial setup script..."
    
    # Build init script arguments from configuration
    init_args=""
    [ "$INTERACTIVE" = false ] && init_args="$init_args --non-interactive"
    init_args="$init_args --temp-dir \"$TEMP_DIR\""
    init_args="$init_args --config \"$CONFIG_FILE\""
    
    # Run init script
    eval "bash \"$TEMP_DIR/init/init.sh\" $init_args"
    
    if [ $? -ne 0 ]; then
        print_error "Initial setup failed"
        exit 1
    fi
    
    print_success "Initial setup completed successfully"
    touch "$TEMP_DIR/init/.init_completed"
else
    print_info "Initial setup already completed, skipping..."
fi

# Interactive confirmation
if [ "$INTERACTIVE" = true ]; then
    echo ""
    print_info "=== Installation Configuration ==="
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

# Installation counter
INSTALLED_COUNT=0
FAILED_COUNT=0

# Install components
if [ "$INSTALL_THEME" = true ]; then
    if run_installation "$TEMP_DIR/theme/install_theme.sh" "Theme customization" "-n"; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

if [ "$INSTALL_X735" = true ]; then
    if run_installation "$TEMP_DIR/x735/x735_install.sh" "X735 power management" "-n"; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

if [ "$INSTALL_GPS" = true ]; then
    if run_installation "$TEMP_DIR/gps-berry/gpsberry_install.sh" "GPS functionality" ""; then
        ((INSTALLED_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
fi

# Show installation summary
show_summary "$INSTALLED_COUNT" "$FAILED_COUNT"

# Clean up if configured
if [ "$CONFIG_cleanup_temp" = true ] || ([ "$INTERACTIVE" = true ] && [ -z "$CONFIG_cleanup_temp" ]); then
    if [ "$INTERACTIVE" = true ]; then
        echo -n "Remove temporary installation files? [Y/n]: "
        read -r cleanup_confirm
        if [[ ! "$cleanup_confirm" =~ ^[Nn]$ ]]; then
            rm -rf "$TEMP_DIR"
            print_success "Temporary files cleaned up"
        fi
    else
        rm -rf "$TEMP_DIR"
        print_success "Temporary files cleaned up"
    fi
fi

# Handle reboot
prompt_reboot "$INTERACTIVE" "$DO_REBOOT"
