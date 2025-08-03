#!/bin/bash

# GPSBerry Interactive Installation Script
# Enhanced version with improved user interaction and non-interactive mode
# This script prepares the Raspberry Pi for GPS communication
# by installing necessary packages, configuring serial ports,
# and setting up a post-reboot script to finalize GPS daemon configuration.
## It is designed to be run on Raspberry Pi OS.
## Usage: Run this script as root or with sudo privileges.
## Author: Mikey Nichols

# Fallback functions if utils.sh is not available
# These will be overridden by utils.sh if it's loaded

# Fallback color codes for better visual feedback (if utils.sh not loaded)
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
fi

# Fallback functions (will be overridden if utils.sh is loaded)
if ! command -v print_info >/dev/null 2>&1; then
    print_info() { echo -e "${BLUE}ℹ  $@${NC}"; }
    print_success() { echo -e "${GREEN}✓ $@${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠  $@${NC}"; }
    print_error() { echo -e "${RED}✗ $@${NC}"; }
    
    log_message() {
        local level=$1
        shift
        local message="$@"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    }
fi

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$SCRIPT_DIR/../essentials/utils.sh"

if [ -f "$UTILS_PATH" ]; then
    source "$UTILS_PATH"
    echo "✓ Loaded shared utilities from: $UTILS_PATH"
else
    echo "⚠ Warning: Shared utilities not found at: $UTILS_PATH"
    echo "   Continuing with local functions..."
fi

# Global variables
INTERACTIVE=true
DRY_RUN=false
LOG_FILE="/tmp/gpsberry-install.log"
POST_SCRIPT_SOURCE="/var/tmp/raspberry-config/gps-berry/post-reboot.sh"
POST_SCRIPT_TEMP="/tmp/post-reboot-gps.sh"

# Function to display usage information
show_usage() {
    echo "GPSBerry Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -n, --non-interactive  Run in non-interactive mode (auto-confirm all prompts)"
    echo "  -d, --dry-run       Show what would be done without making changes"
    echo "  -l, --log FILE      Specify custom log file (default: $LOG_FILE)"
    echo "  -s, --skip-update   Skip system update step"
    echo "  -v, --verbose       Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  $0                          # Interactive mode"
    echo "  $0 --non-interactive        # Automated installation"
    echo "  $0 --dry-run                # Preview changes"
    echo "  $0 -n --skip-update         # Non-interactive, skip updates"
}

# GPS-specific status functions
print_status() {
    print_info "$@"
}

# Function to print colored output (enhanced version using utils or fallback)
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to ask yes/no questions
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    
    if [ "$INTERACTIVE" = false ]; then
        print_status "Non-interactive mode: defaulting to '$default' for: $prompt"
        return 0
    fi
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt (Y/n): " -n 1 -r
        else
            read -p "$prompt (y/N): " -n 1 -r
        fi
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ $default == "y" ]]); then
            return 0
        elif [[ $REPLY =~ ^[Nn]$ ]] || ([[ -z $REPLY ]] && [[ $default == "n" ]]); then
            return 1
        else
            print_warning "Please answer y or n."
        fi
    done
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r${CYAN}[${NC}"
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed)) | tr ' ' '-'
    printf "${CYAN}]${NC} %d%% %s" $percentage "$description"
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Function to check if we're running on Raspberry Pi
check_raspberry_pi() {
    print_status "Checking if running on Raspberry Pi..."
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would check Raspberry Pi compatibility"
        return 0
    fi
    
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_warning "This doesn't appear to be a Raspberry Pi"
        print_warning "Device info: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
        
        if ! ask_yes_no "Continue anyway?" "n"; then
            print_error "Installation cancelled."
            exit 1
        fi
    else
        local pi_model=$(grep "Model" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        print_success "Detected: $pi_model"
    fi
}

# Function to show current serial configuration with enhanced details
show_serial_status() {
    print_status "Analyzing current serial port configuration..."
    echo
    print_color $CYAN "=== Current Serial Port Status ==="
    
    # Check console assignment
    echo "Serial console status:"
    if dmesg | grep -q "console.*tty.*enabled"; then
        dmesg | grep "console.*tty" | tail -2 | sed 's/^/  /'
    else
        echo "  No console information found"
    fi
    
    # Check serial device links
    echo
    echo "Serial device aliases:"
    if [ -L /dev/serial0 ]; then
        ls -l /dev/serial0 | sed 's/^/  /'
        print_success "serial0 alias exists" | sed 's/^/  /'
    else
        print_warning "serial0 alias not found" | sed 's/^/  /'
    fi
    
    if [ -L /dev/serial1 ]; then
        ls -l /dev/serial1 | sed 's/^/  /'
    fi
    
    # Check current configuration files
    echo
    echo "Configuration status:"
    if grep -q "enable_uart=1" /boot/config.txt 2>/dev/null; then
        echo "  ✓ UART enabled in /boot/config.txt"
    else
        echo "  ⚠ UART not enabled in /boot/config.txt"
    fi
    
    if grep -q "console=serial" /boot/cmdline.txt 2>/dev/null; then
        echo "  ⚠ Serial console enabled in /boot/cmdline.txt"
    else
        echo "  ✓ Serial console not found in /boot/cmdline.txt"
    fi
    
    # Check if GPSD is already installed
    echo
    echo "GPS software status:"
    if dpkg -l | grep -q "gpsd"; then
        echo "  ✓ GPSD already installed"
        dpkg -l | grep -E "(gpsd|gpsd-clients)" | awk '{print "    " $2 " " $3}'
    else
        echo "  ⚠ GPSD not installed"
    fi
    
    echo
}

# Function to update system with progress
update_system() {
    if [ "$SKIP_UPDATE" = true ]; then
        print_status "Skipping system update as requested"
        return 0
    fi
    
    print_status "Updating system packages..."
    echo "This may take several minutes..."
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would run 'apt update && apt upgrade -y'"
        return 0
    fi
    
    # Create a temporary script to show progress
    {
        echo "Updating package lists..."
        sudo apt update 2>&1
        echo "Upgrading packages..."
        sudo apt upgrade -y 2>&1
    } | while IFS= read -r line; do
        echo "$line" >> "$LOG_FILE"
        # Show dots for progress
        echo -n "."
    done
    
    local exit_code=${PIPESTATUS[0]}
    echo # New line after dots
    
    if [ $exit_code -eq 0 ]; then
        print_success "System updated successfully"
    else
        print_error "System update failed (exit code: $exit_code)"
        print_warning "Check log file: $LOG_FILE"
        
        if ! ask_yes_no "Continue with installation?" "n"; then
            exit 1
        fi
    fi
    echo
}

# Function to install GPS packages with dependency checking
install_gps_packages() {
    print_status "Installing GPS packages..."
    
    local packages="gpsd gpsd-clients python3-gps minicom"
    print_status "Packages to install: $packages"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would install: $packages"
        return 0
    fi
    
    # Use shared install function if available, otherwise fallback
    if command -v install_packages >/dev/null 2>&1; then
        print_status "Using shared package installation function..."
        if install_packages $packages; then
            print_success "GPS packages installed successfully using shared utilities"
        else
            print_error "Failed to install GPS packages"
            exit 1
        fi
    else
        # Fallback to local implementation
        print_status "Using local package installation..."
        
        # Check if packages are available
        for package in $packages; do
            if ! apt-cache show "$package" >/dev/null 2>&1; then
                print_warning "Package '$package' not available in repositories"
            fi
        done
        
        if sudo apt-get install $packages -y; then
            print_success "GPS packages installed successfully"
        else
            print_error "Failed to install GPS packages"
            exit 1
        fi
    fi
    
    # Show installed versions
    echo "Installed versions:"
    dpkg -l | grep -E "(gpsd|gpsd-clients|python3-gps|minicom)" | awk '{print "  " $2 " " $3}'
    
    # Check service status
    if systemctl is-enabled gpsd >/dev/null 2>&1; then
        print_status "GPSD service: $(systemctl is-enabled gpsd)"
    fi
    
    echo
}

# Function to configure serial port with backup
configure_serial() {
    print_status "Configuring serial port..."
    print_status "Disabling serial console but enabling serial port hardware..."
    print_status "This is equivalent to: raspi-config -> Interfacing -> Serial -> No -> Yes"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would configure serial port using raspi-config"
        return 0
    fi
    
    # Backup configuration files using shared function if available
    print_status "Creating configuration backups..."
    if command -v backup_file >/dev/null 2>&1; then
        backup_file "/boot/config.txt"
        backup_file "/boot/cmdline.txt"
    else
        # Fallback backup method
        sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)
        sudo cp /boot/cmdline.txt /boot/cmdline.txt.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    if sudo raspi-config nonint do_serial 2; then
        print_success "Serial configuration updated"
        
        # Verify configuration
        echo
        print_status "Verifying configuration changes:"
        
        if grep -q "enable_uart=1" /boot/config.txt; then
            print_success "UART enabled in /boot/config.txt"
        else
            print_warning "UART setting not found in /boot/config.txt"
        fi
        
        if ! grep -q "console=serial" /boot/cmdline.txt; then
            print_success "Serial console disabled in /boot/cmdline.txt"
        else
            print_warning "Serial console may still be enabled"
        fi
        
    else
        print_error "Failed to configure serial port"
        print_error "You may need to manually configure using raspi-config"
        exit 1
    fi
    echo
}

# Function to setup post-reboot script with enhanced error handling
setup_post_reboot() {
    print_status "Setting up post-reboot configuration..."
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would setup post-reboot script"
        if [ -f "$POST_SCRIPT_SOURCE" ]; then
            print_status "Found post-reboot script: $POST_SCRIPT_SOURCE"
        else
            print_warning "Post-reboot script not found: $POST_SCRIPT_SOURCE"
        fi
        return 0
    fi
    
    # Check if post-reboot script exists
    if [ -f "$POST_SCRIPT_SOURCE" ]; then
        print_success "Found post-reboot script: $POST_SCRIPT_SOURCE"
        
        # Copy to temp location
        if sudo cp "$POST_SCRIPT_SOURCE" "$POST_SCRIPT_TEMP"; then
            print_success "Post-reboot script copied to $POST_SCRIPT_TEMP"
        else
            print_error "Failed to copy post-reboot script"
            exit 1
        fi
        
        # Make executable
        if sudo chmod +x "$POST_SCRIPT_TEMP"; then
            print_success "Post-reboot script made executable"
        else
            print_error "Failed to make post-reboot script executable"
            exit 1
        fi
        
        # Add to crontab for one-time execution
        # First, backup existing crontab
        sudo crontab -l > /tmp/crontab.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        if (sudo crontab -l 2>/dev/null; echo "@reboot $POST_SCRIPT_TEMP") | sudo crontab -; then
            print_success "Post-reboot script scheduled via crontab"
            print_status "Script will run once after reboot and configure GPS daemon"
        else
            print_error "Failed to schedule post-reboot script"
            exit 1
        fi
        
    else
        print_warning "Post-reboot script not found at: $POST_SCRIPT_SOURCE"
        print_warning "You'll need to manually configure GPSD after reboot"
        
        if ! ask_yes_no "Continue without post-reboot script?" "n"; then
            exit 1
        fi
    fi
    echo
}

# Function to show comprehensive installation summary
show_installation_summary() {
    print_color $CYAN "=================================================="
    print_color $CYAN "           Installation Summary"
    print_color $CYAN "=================================================="
    echo
    
    print_color $GREEN "✓ Changes made:"
    echo "  • System packages updated (unless skipped)"
    echo "  • GPS packages installed (gpsd, gpsd-clients, python3-gps, minicom)"
    echo "  • Serial console disabled, hardware enabled"
    echo "  • Configuration files backed up"
    if [ -f "$POST_SCRIPT_TEMP" ]; then
        echo "  • Post-reboot script scheduled"
    fi
    echo
    
    print_color $BLUE "ℹ  After reboot:"
    echo "  • Serial port will be available at /dev/serial0"
    if [ -f "$POST_SCRIPT_TEMP" ]; then
        echo "  • GPS daemon will be automatically configured"
    else
        echo "  • You'll need to manually configure GPSD"
    fi
    echo "  • Test GPS with: cat /dev/serial0"
    echo "  • Or use: sudo minicom -b 9600 -o -D /dev/serial0"
    echo "  • Python GPS: sudo python3 -c 'import gps; print(\"GPS module available\")'"
    echo
    
    print_color $YELLOW "📋 Expected GPS output:"
    echo "  NMEA sentences like: \$GPGGA, \$GPRMC, \$GPGSV, etc."
    echo
    
    print_color $CYAN "📄 Log file: $LOG_FILE"
    echo
}

# Function to run post-install script
run_postinstall_script() {
    print_status "Running post-installation setup..."
    
    local postinstall_script="$(dirname "$0")/gpsberry_postinstall.sh"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would run post-install script: $postinstall_script"
        return 0
    fi
    
    if [ -f "$postinstall_script" ]; then
        print_status "Found post-install script: $postinstall_script"
        
        # Make sure it's executable
        chmod +x "$postinstall_script"
        
        # Run the post-install script
        if "$postinstall_script"; then
            print_success "Post-installation setup completed successfully"
        else
            print_warning "Post-installation setup failed (exit code: $?)"
            print_warning "You may need to run manually: sudo $postinstall_script"
        fi
    else
        print_warning "Post-install script not found: $postinstall_script"
        print_warning "GPSBerry tools and shortcuts will not be installed"
        print_status "You can run it manually later if needed"
    fi
    echo
}

# Function to handle cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Installation failed with exit code $exit_code"
        print_status "Check log file for details: $LOG_FILE"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Parse command line arguments
SKIP_UPDATE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -n|--non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -s|--skip-update)
            SKIP_UPDATE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main installation flow
main() {
    # Initialize log file
    echo "GPSBerry Installation Log - $(date)" > "$LOG_FILE"
    
    # Show script header
    print_color $CYAN "=================================================="
    print_color $CYAN "        GPSBerry Interactive Installation"
    print_color $CYAN "=================================================="
    echo
    
    if [ "$INTERACTIVE" = false ]; then
        print_status "Running in NON-INTERACTIVE mode"
    fi
    
    if $DRY_RUN; then
        print_warning "DRY RUN mode - no changes will be made"
    fi
    
    echo
    
    # Installation steps
    local total_steps=7
    local current_step=0
    
    show_progress $((++current_step)) $total_steps "Checking Raspberry Pi..."
    check_raspberry_pi
    
    show_progress $((++current_step)) $total_steps "Analyzing serial status..."
    show_serial_status
    
    if [ "$INTERACTIVE" = true ]; then
        if ! ask_yes_no "Proceed with GPSBerry installation?" "y"; then
            print_status "Installation cancelled by user."
            exit 0
        fi
    fi
    
    show_progress $((++current_step)) $total_steps "Updating system..."
    update_system
    
    show_progress $((++current_step)) $total_steps "Installing GPS packages..."
    install_gps_packages
    
    show_progress $((++current_step)) $total_steps "Configuring serial port..."
    configure_serial
    
    show_progress $((++current_step)) $total_steps "Setting up post-reboot script..."
    setup_post_reboot
    
    # Run post-install script to setup tools and shortcuts
    run_postinstall_script
    
    show_installation_summary
    
    if $DRY_RUN; then
        print_status "DRY RUN complete - no changes were made"
        exit 0
    fi
    
    print_status "Installation complete! Ready to reboot."
    print_status "The system will automatically configure GPS after restart."
    
    if ask_yes_no "Reboot now?" "y"; then
        print_status "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        for i in {5..1}; do
            echo -n "$i... "
            sleep 1
        done
        echo
        print_status "Rebooting now..."
        sudo reboot
    else
        print_warning "Manual reboot required to complete installation."
        print_status "Run: sudo reboot"
    fi
}

# Check if running as root/sudo (use shared function if available)
if command -v check_permissions >/dev/null 2>&1; then
    if [ "$DRY_RUN" = false ] && ! check_permissions; then
        print_status "Try: sudo $0 $*"
        exit 1
    fi
else
    # Fallback permission check
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        print_error "This script must be run as root or with sudo privileges"
        print_status "Try: sudo $0 $*"
        exit 1
    fi
fi

# Run main function with all arguments
main "$@"