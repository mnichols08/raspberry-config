#!/bin/bash

# Interactive GeekWorm X735 Power Management Board Installation Script
# Usage: sudo ./install_x735.sh [--non-interactive] [--temp-dir PATH]
#        --non-interactive: Run without prompts, auto-reboot at end
#         -y: Alias for --non-interactive
#        --temp-dir PATH: Specify custom temporary directory (default: /var/tmp/raspberry-config)
#        --help: Show this help message
#        -h: Alias for --help
# Author: Mikey Nichols

set -e  # Exit on any error

# Global flag for non-interactive mode
NON_INTERACTIVE=false

# Global variable for temporary directory
TEMP_DIR="/var/tmp/raspberry-config"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive | -y)
                NON_INTERACTIVE=true
                shift
                ;;
            --temp-dir)
                TEMP_DIR="$2"
                shift 2
                ;;
            -h|--help)
                echo "GeekWorm X735 Power Management Board Installation Script"
                echo ""
                echo "Usage: sudo $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --non-interactive    Run without user prompts and auto-reboot"
                echo "  --temp-dir PATH      Specify custom temporary directory (default: /var/tmp/raspberry-config)"
                echo "  -h, --help          Show this help message"
                echo ""
                echo "When run without --non-interactive:"
                echo "  - Will prompt before continuing if config.txt is missing"
                echo "  - Will ask if you want to reboot at the end"
                echo ""
                echo "When run with --non-interactive:"
                echo "  - Will exit with error if config.txt is missing"
                echo "  - Will automatically reboot at the end"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Validate temp directory path
    if [[ -z "$TEMP_DIR" ]]; then
        print_error "Temporary directory cannot be empty"
        exit 1
    fi
    
    # Ensure temp directory is absolute path
    if [[ "$TEMP_DIR" != /* ]]; then
        print_error "Temporary directory must be an absolute path"
        exit 1
    fi
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running on Raspberry Pi
check_raspberry_pi() {
    print_status "Checking if running on Raspberry Pi..."
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        print_error "This script is designed for Raspberry Pi systems only!"
        return 1
    fi
    
    local model=$(cat /proc/device-tree/model 2>/dev/null)
    print_success "Detected: $model"
    return 0
}

# Function to check if running as root/sudo
check_privileges() {
    print_status "Checking user privileges..."
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo privileges"
        echo "Please run: sudo $0"
        return 1
    fi
    print_success "Running with appropriate privileges"
    return 0
}

# Function to backup config.txt
backup_config() {
    print_status "Creating backup of /boot/config.txt..."
    if [[ -f /boot/config.txt ]]; then
        cp /boot/config.txt "/boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backup created successfully"
    else
        print_warning "/boot/config.txt not found - this may not be a standard Raspberry Pi OS installation"
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            print_error "Non-interactive mode: Cannot continue without /boot/config.txt"
            return 1
        else
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    fi
    return 0
}

# Function to add overlay to config.txt
add_overlay() {
    print_status "Adding PWM overlay to /boot/config.txt..."
    
    # Check if overlay already exists
    if grep -q "dtoverlay=pwm-2chan,pin2=13,func2=4" /boot/config.txt 2>/dev/null; then
        print_warning "PWM overlay already exists in config.txt"
        return 0
    fi
    
    # Check if [all] section exists
    if ! grep -q "^\[all\]" /boot/config.txt 2>/dev/null; then
        print_warning "[all] section not found in config.txt"
        echo "[all]" >> /boot/config.txt
        print_status "Added [all] section to config.txt"
    fi
    
    # Add the overlay
    sed -i '/^\[all\]/a dtoverlay=pwm-2chan,pin2=13,func2=4' /boot/config.txt
    print_success "PWM overlay added to config.txt"
    return 0
}

# Function to install required packages
install_packages() {
    print_status "Updating package list..."
    if ! apt update; then
        print_error "Failed to update package list"
        return 1
    fi
    
    print_status "Installing required packages..."
    local packages=("gpiod" "python3-rpi.gpio")
    
    for package in "${packages[@]}"; do
        print_status "Installing $package..."
        if apt install -y "$package"; then
            print_success "$package installed successfully"
        else
            print_error "Failed to install $package"
            return 1
        fi
    done
    
    return 0
}

# Function to setup temporary installation directory
# This function will ensure the x735 installation files are available
# and copy them to the working directory structure
setup_temp_directory() {
    print_status "Setting up temporary directory..."
    
    local temp_dir="$TEMP_DIR"
    local temp_x735_dir="$temp_dir/x735"
    local source_x735_dir
    
    # Create temp directory if it doesn't exist
    if [[ ! -d "$temp_dir" ]]; then
        mkdir -p "$temp_dir"
        print_success "Created temporary directory: $temp_dir"
    fi
    
    # Determine the source directory based on script location
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if we're running from within the repository structure
    if [[ -d "$script_dir/install_files" ]]; then
        source_x735_dir="$script_dir"
        print_status "Found X735 files in script directory: $source_x735_dir"
    elif [[ -d "$script_dir/../x735/install_files" ]]; then
        source_x735_dir="$script_dir/../x735"
        print_status "Found X735 files in parent directory: $source_x735_dir"
    else
        # Try to update submodule if we're in a git repository
        print_status "Checking for X735 script submodule..."
        if command -v git >/dev/null 2>&1; then
            local repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
            if [[ -n "$repo_root" ]] && [[ -f "$repo_root/.gitmodules" ]]; then
                print_status "Found git repository, updating submodules..."
                if git -C "$repo_root" submodule update --init --recursive; then
                    print_success "Submodules updated successfully"
                    if [[ -d "$repo_root/x735/install_files" ]]; then
                        source_x735_dir="$repo_root/x735"
                        print_success "Found X735 files after submodule update: $source_x735_dir"
                    fi
                else
                    print_error "Failed to update submodules"
                    return 1
                fi
            fi
        fi
        
        # If still not found, error out
        if [[ -z "$source_x735_dir" ]]; then
            print_error "X735 install files not found. Please ensure you're running from the correct directory or that submodules are initialized."
            return 1
        fi
    fi
    
    # Verify source directory has required files before copying
    local source_install_dir="$source_x735_dir/install_files"
    local required_scripts=("install-fan-service.sh" "install-pwr-service.sh" "xSoft.sh" "install-sss.sh")
    
    print_status "Verifying source files exist..."
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$source_install_dir/$script" ]]; then
            print_error "Required script not found in source: $source_install_dir/$script"
            print_error "The submodule may not be properly initialized."
            
            # Try to initialize/update submodule one more time
            if command -v git >/dev/null 2>&1; then
                local repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
                if [[ -n "$repo_root" ]]; then
                    print_status "Attempting to reinitialize submodule..."
                    if git -C "$repo_root" submodule update --init --recursive --force; then
                        if [[ -f "$source_install_dir/$script" ]]; then
                            print_success "Submodule reinitialized successfully"
                        else
                            print_error "Submodule reinitialization failed"
                            return 1
                        fi
                    else
                        print_error "Failed to reinitialize submodule"
                        return 1
                    fi
                fi
            else
                return 1
            fi
        fi
    done
    print_success "All required source files found"
    
    # Copy the x735 directory to temp location
    print_status "Copying X735 files to temporary directory..."
    if cp -r "$source_x735_dir" "$temp_x735_dir"; then
        print_success "X735 files copied to: $temp_x735_dir"
    else
        print_error "Failed to copy X735 files"
        return 1
    fi
    
    # Verify copied files exist
    local x735_install_dir="$temp_x735_dir/install_files"
    print_status "Verifying copied files..."
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$x735_install_dir/$script" ]]; then
            print_error "Required script not found after copy: $x735_install_dir/$script"
            return 1
        fi
    done
    print_success "All required files verified in temporary directory"
    
    # Set execute permissions on scripts
    print_status "Setting execute permissions on scripts..."
    chmod +x "$x735_install_dir"/*.sh 2>/dev/null || true
    if [[ -d "$temp_x735_dir/bin" ]]; then
        chmod +x "$temp_x735_dir/bin"/*.py "$temp_x735_dir/bin"/*.sh 2>/dev/null || true
    fi
    print_success "Execute permissions set"
    
    return 0
}

# Function to install services
install_services() {
    local x735_dir="$TEMP_DIR/x735/install_files"
    
    print_status "Installing X735 fan service..."
    if "$x735_dir/install-fan-service.sh"; then
        print_success "Fan service installed successfully"
    else
        print_error "Failed to install fan service"
        return 1
    fi
    
    print_status "Installing X735 power service..."
    if "$x735_dir/install-pwr-service.sh"; then
        print_success "Power service installed successfully"
    else
        print_error "Failed to install power service"
        return 1
    fi
    
    print_status "Installing X735 safe shutdown script service..."
    if "$x735_dir/install-sss.sh"; then
        print_success "Safe shutdown script service installed successfully"
    else
        print_error "Failed to install safe shutdown script service"
        return 1
    fi
    
    return 0
}

# Function to install xSoft utility
install_xsoft() {
    local x735_dir="$TEMP_DIR/x735/install_files"
    local x735_bin_dir="$TEMP_DIR/x735/bin"
    
    print_status "Installing xSoft utility..."
    
    # Copy xSoft.sh to local bin
    if cp -f "$x735_dir/xSoft.sh" /usr/local/bin/; then
        print_success "xSoft.sh copied to /usr/local/bin/"
    else
        print_error "Failed to copy xSoft.sh"
        return 1
    fi
    
    # Create symlink
    if [[ -L /usr/local/bin/xSoft ]]; then
        print_warning "xSoft symlink already exists, removing old one..."
        rm /usr/local/bin/xSoft
    fi
    
    if ln -s /usr/local/bin/xSoft.sh /usr/local/bin/xSoft; then
        print_success "xSoft symlink created"
    else
        print_error "Failed to create xSoft symlink"
        return 1
    fi
    
    # Create x735 directory in /usr/local/bin
    print_status "Creating /usr/local/bin/x735 directory..."
    if mkdir -p /usr/local/bin/x735; then
        print_success "/usr/local/bin/x735 directory created"
    else
        print_error "Failed to create /usr/local/bin/x735 directory"
        return 1
    fi

    
    # Copy bin contents to /usr/local/bin/x735
    if [[ -d "$x735_bin_dir" ]]; then
        print_status "Copying X735 bin contents to /usr/local/bin/x735..."
        if cp -f "$x735_bin_dir"/* /usr/local/bin/x735/; then
            print_success "X735 bin contents copied to /usr/local/bin/x735/"
            
            # Make scripts executable
            chmod +x /usr/local/bin/x735/*.py /usr/local/bin/x735/*.sh 2>/dev/null || true
            print_success "Execute permissions set on X735 scripts"
        else
            print_error "Failed to copy X735 bin contents"
            return 1
        fi
    else
        print_warning "X735 bin directory not found at $x735_bin_dir"
    fi
    
    return 0
}

# Function to create x735off script
create_power_off_script() {
    print_status "Creating x735off power-down script..."
    
    local script_content='#!/bin/bash
# X735 Power Board Safe Shutdown Script
# This script will safely power down the X735 board and Raspberry Pi
xSoft 0 20'
    
    if echo "$script_content" > /usr/local/bin/x735off; then
        print_success "x735off script created at /usr/local/bin/x735off"
    else
        print_error "Failed to create x735off script"
        return 1
    fi
    
    if chmod +x /usr/local/bin/x735off; then
        print_success "x735off script made executable"
    else
        print_error "Failed to make x735off script executable"
        return 1
    fi
    
    return 0
}

# Function to create start menu entries
create_start_menu_entries() {
    print_status "Creating start menu entries..."
    
    # Get the default user (not root, in case running with sudo)
    local default_user="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
    local user_home
    
    # Try to get the user's home directory
    if [[ -n "$SUDO_USER" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        user_home="$HOME"
    fi
    
    # Fallback if we can't determine user home
    if [[ -z "$user_home" ]] || [[ "$user_home" == "/root" ]]; then
        print_warning "Could not determine user home directory, trying /home/pi"
        user_home="/home/pi"
        default_user="pi"
    fi
    
    print_status "Creating start menu entries for user: $default_user (home: $user_home)"
    
    # Create applications directory if it doesn't exist
    local apps_dir="$user_home/.local/share/applications"
    if mkdir -p "$apps_dir"; then
        print_success "Applications directory created: $apps_dir"
    else
        print_error "Failed to create applications directory"
        return 1
    fi
    
    # Create .desktop files for each X735 utility
    local utilities=(
        "xSoft:Main X735 Utility:Terminal application for X735 board control"
        "x735off:X735 Safe Shutdown:Safely shutdown the X735 board and Raspberry Pi"
        "pwm_fan_control.py:PWM Fan Control:Direct PWM fan control for X735 board"
        "read_fan_speed.py:Fan Speed Reader:Read current fan speed from X735 board"
        "uninstall.sh:Uninstall X735 Tools:Remove X735 tools and configurations"
    )
    
    for utility in "${utilities[@]}"; do
        IFS=':' read -r cmd name description <<< "$utility"
        
        local desktop_file="$apps_dir/x735-$cmd.desktop"
        
        # Determine the correct executable path and command
        local exec_cmd
        local icon="utilities-terminal"
        
        case "$cmd" in
            "xSoft")
                exec_cmd="x-terminal-emulator -e 'bash -c \"xSoft --help; echo; echo Press Enter to exit...; read\"'"
                ;;
            "x735off")
                exec_cmd="x-terminal-emulator -e 'bash -c \"echo Are you sure you want to shutdown? Press Enter to continue or Ctrl+C to cancel...; read; x735off\"'"
                ;;
            "pwm_fan_control.py")
                exec_cmd="x-terminal-emulator -e 'bash -c \"echo X735 PWM Fan Control; echo Usage: python3 /usr/local/bin/x735/pwm_fan_control.py [speed]; echo; echo Press Enter to exit...; read\"'"
                ;;
            "read_fan_speed.py")
                exec_cmd="x-terminal-emulator -e 'bash -c \"python3 /usr/local/bin/x735/read_fan_speed.py; echo; echo Press Enter to exit...; read\"'"
                ;;
        esac
        
        # Create the .desktop file content
        local desktop_content="[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$description
Exec=$exec_cmd
Icon=$icon
Terminal=false
Categories=System;HardwareSettings;
Keywords=X735;Fan;Power;GeekWorm;Raspberry;Pi;"
        
        # Write the .desktop file
        if echo "$desktop_content" > "$desktop_file"; then
            print_success "Created start menu entry: $desktop_file"
            
            # Make it executable
            chmod +x "$desktop_file"
            
            # Change ownership to the actual user
            if [[ -n "$default_user" ]] && [[ "$default_user" != "root" ]]; then
                chown "$default_user:$default_user" "$desktop_file" 2>/dev/null || true
            fi
        else
            print_error "Failed to create start menu entry: $desktop_file"
            return 1
        fi
    done
    
    # Create a main X735 folder in the applications menu
    local folder_file="$apps_dir/x735-tools.directory"
    local folder_content="[Desktop Entry]
Version=1.0
Type=Directory
Name=X735 Tools
Comment=GeekWorm X735 Power Management Board Tools
Icon=folder-system"
    
    if echo "$folder_content" > "$folder_file"; then
        print_success "Created X735 tools folder entry"
        # Change ownership to the actual user
        if [[ -n "$default_user" ]] && [[ "$default_user" != "root" ]]; then
            chown "$default_user:$default_user" "$folder_file" 2>/dev/null || true
        fi
    fi
    
    # Fix ownership of the entire .local/share/applications directory
    if [[ -n "$default_user" ]] && [[ "$default_user" != "root" ]]; then
        chown -R "$default_user:$default_user" "$user_home/.local" 2>/dev/null || true
    fi
    
    print_success "Start menu entries created successfully"
    return 0
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    local checks_passed=0
    local total_checks=6
    
    # Check if overlay was added
    if grep -q "dtoverlay=pwm-2chan,pin2=13,func2=4" /boot/config.txt 2>/dev/null; then
        print_success "✓ PWM overlay found in config.txt"
        ((checks_passed++))
    else
        print_error "✗ PWM overlay not found in config.txt"
    fi
    
    # Check if xSoft utility exists and is executable
    if [[ -x /usr/local/bin/xSoft.sh ]] && [[ -L /usr/local/bin/xSoft ]]; then
        print_success "✓ xSoft utility installed and accessible"
        ((checks_passed++))
    else
        print_error "✗ xSoft utility not properly installed"
    fi
    
    # Check if x735off script exists and is executable
    if [[ -x /usr/local/bin/x735off ]]; then
        print_success "✓ x735off power-down script installed"
        ((checks_passed++))
    else
        print_error "✗ x735off power-down script not found"
    fi
    
    # Check if x735 directory and scripts exist
    if [[ -d /usr/local/bin/x735 ]] && [[ -f /usr/local/bin/x735/pwm_fan_control.py ]] && [[ -f /usr/local/bin/x735/read_fan_speed.py ]] && [[ -f /usr/local/bin/x735/uninstall.sh ]]; then
        print_success "✓ X735 utility scripts directory installed"
        ((checks_passed++))
    else
        print_error "✗ X735 utility scripts directory not found or incomplete"

    fi
    
    # Check if services are installed (basic check)
    if systemctl list-unit-files | grep -q x735; then
        print_success "✓ X735 services appear to be installed"
        ((checks_passed++))
    else
        print_error "✗ X735 services not found"
    fi
    
    # Check if start menu entries were created
    local default_user="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
    local user_home
    if [[ -n "$SUDO_USER" ]]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        user_home="$HOME"
    fi
    if [[ -z "$user_home" ]] || [[ "$user_home" == "/root" ]]; then
        user_home="/home/pi"
    fi
    
    if [[ -f "$user_home/.local/share/applications/x735-xSoft.desktop" ]]; then
        print_success "✓ Start menu entries created"
        ((checks_passed++))
    else
        print_error "✗ Start menu entries not found"
    fi
    
    echo
    print_status "Installation verification: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_success "All checks passed! Installation appears successful."
        return 0
    else
        print_warning "Some checks failed. Installation may be incomplete."
        return 1
    fi
}

# Function to display post-installation information
show_post_install_info() {
    echo
    print_success "=== X735 Power Management Board Installation Complete ==="
    echo
    echo "Next steps:"
    echo "1. Reboot your Raspberry Pi to enable the PWM overlay"
    echo "2. After reboot, the X735 services should start automatically"
    echo
    echo "Available commands:"
    echo "  • xSoft - Main X735 utility (see xSoft --help for options)"
    echo "  • x735off - Safe shutdown script for X735 board"
    echo
    echo "Available utility scripts in /usr/local/bin/x735/:"
    echo "  • pwm_fan_control.py - Direct PWM fan control script"
    echo "  • read_fan_speed.py - Read current fan speed script"
    echo "  • uninstall.sh - Uninstallation script"
    echo
    echo "Start menu and application launcher:"
    echo "  • Look for 'X735 Tools' in your application menu"
    echo "  • Individual tools are available in the Applications menu"
    echo
    echo "To check service status after reboot:"
    echo "  • sudo systemctl status x735-fan"
    echo "  • sudo systemctl status x735-pwr"
    echo
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        print_status "Non-interactive mode: Automatic reboot will occur shortly..."
    else
        print_warning "A reboot is required for the PWM overlay to take effect!"
    fi
    echo
}

# Main installation function
install_x735() {
    echo
    print_status "=== Starting GeekWorm X735 Power Management Board Installation ==="
    print_status "Using temporary directory: $TEMP_DIR"
    echo
    
    # Run all installation steps
    check_raspberry_pi || return 1
    check_privileges || return 1
    backup_config || return 1
    add_overlay || return 1
    install_packages || return 1
    setup_temp_directory || return 1
    install_services || return 1
    install_xsoft || return 1
    create_power_off_script || return 1
    create_start_menu_entries || return 1
    verify_installation
    show_post_install_info
    
    return 0
}

# If script is being run directly (not sourced), execute the installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_arguments "$@"
    
    install_x735
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Installation completed successfully!"
        echo
        
        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            print_status "Non-interactive mode: Rebooting in 5 seconds... Press Ctrl+C to cancel"
            sleep 5
            reboot
        else
            read -p "Would you like to reboot now to enable the changes? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Rebooting in 5 seconds... Press Ctrl+C to cancel"
                sleep 5
                reboot
            else
                print_warning "Remember to reboot later to enable the PWM overlay!"
            fi
        fi
    else
        print_error "Installation failed with exit code $exit_code"
        exit $exit_code
    fi
fi