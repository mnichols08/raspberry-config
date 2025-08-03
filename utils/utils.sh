#!/bin/bash

# Raspberry Pi Configuration Utility Functions
# Common functions used across multiple scripts
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

# Function to log messages with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local log_file="/var/log/raspberry-config/install.log"
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$log_file")"
    
    # Log with timestamp
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$log_file"
}

# Function to load configuration from file
load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        print_info "Loading configuration from: $config_file"
        log_message "INFO" "Loading configuration from: $config_file"
        
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
            
            # Export the variable so it's available to calling script
            export "CONFIG_$key"="$value"
            
        done < "$config_file"
        
        return 0
    else
        print_warning "Configuration file not found: $config_file"
        log_message "WARNING" "Configuration file not found: $config_file"
        return 1
    fi
}

# Function to check if running with proper permissions
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        log_message "ERROR" "Script run without proper permissions (not root/sudo)"
        return 1
    fi
    return 0
}

# Function to check if a package is installed
is_package_installed() {
    local package="$1"
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
}

# Function to install packages with error checking
install_packages() {
    local packages="$*"
    
    print_info "Installing packages: $packages"
    log_message "INFO" "Installing packages: $packages"
    
    # Update package lists first
    apt update
    if [ $? -ne 0 ]; then
        print_error "Failed to update package lists"
        log_message "ERROR" "Failed to update package lists"
        return 1
    fi
    
    # Install packages
    apt install -y $packages
    if [ $? -eq 0 ]; then
        print_success "Packages installed successfully: $packages"
        log_message "SUCCESS" "Packages installed successfully: $packages"
        return 0
    else
        print_error "Failed to install packages: $packages"
        log_message "ERROR" "Failed to install packages: $packages"
        return 1
    fi
}

# Function to safely clone or update git repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local force_fresh="${3:-false}"
    
    print_info "Repository: $repo_url -> $target_dir"
    log_message "INFO" "Repository operation: $repo_url -> $target_dir (force_fresh: $force_fresh)"
    
    # If force_fresh is true, remove existing directory
    if [ "$force_fresh" = true ] && [ -d "$target_dir" ]; then
        print_info "Removing existing directory for fresh clone: $target_dir"
        rm -rf "$target_dir"
    fi
    
    if [ -d "$target_dir/.git" ]; then
        print_info "Repository already exists, updating..."
        cd "$target_dir" && git pull
        local exit_code=$?
    else
        print_info "Cloning repository..."
        git clone "$repo_url" "$target_dir"
        local exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        print_success "Repository operation completed successfully"
        log_message "SUCCESS" "Repository operation completed successfully"
        
        # Make scripts executable
        find "$target_dir" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
        
        return 0
    else
        print_error "Repository operation failed"
        log_message "ERROR" "Repository operation failed with exit code: $exit_code"
        return 1
    fi
}

# Function to fix hostname resolution
fix_hostname_resolution() {
    local current_hostname=$(hostname)
    print_info "Fixing hostname resolution for: $current_hostname"
    log_message "INFO" "Fixing hostname resolution for: $current_hostname"
    
    # Check if hostname is in /etc/hosts
    if ! grep -q "127.0.1.1.*$current_hostname" /etc/hosts; then
        print_info "Adding hostname to /etc/hosts..."
        
        # Remove any existing 127.0.1.1 entries
        sed -i '/^127.0.1.1/d' /etc/hosts
        
        # Add the current hostname
        echo "127.0.1.1       $current_hostname" >> /etc/hosts
        print_success "Hostname resolution configured"
        log_message "SUCCESS" "Hostname resolution configured for: $current_hostname"
    else
        print_info "Hostname already configured in /etc/hosts"
        log_message "INFO" "Hostname already configured in /etc/hosts"
    fi
}

# Function to run installation with error checking
run_installation() {
    local script_path="$1"
    local component_name="$2"
    local args="$3"
    
    print_info "Installing $component_name..."
    log_message "INFO" "Starting installation: $component_name ($script_path)"
    
    if [ ! -f "$script_path" ]; then
        print_error "Installation script not found: $script_path"
        log_message "ERROR" "Installation script not found: $script_path"
        return 1
    fi
    
    # Make script executable
    chmod +x "$script_path"
    
    # Run the installation script
    if [ -n "$args" ]; then
        bash "$script_path" $args
    else
        bash "$script_path"
    fi
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "$component_name installed successfully"
        log_message "SUCCESS" "$component_name installed successfully"
        return 0
    else
        print_error "$component_name installation failed (exit code: $exit_code)"
        log_message "ERROR" "$component_name installation failed (exit code: $exit_code)"
        return 1
    fi
}

# Function to create directory with proper permissions
create_directory() {
    local dir_path="$1"
    local owner="${2:-root}"
    local group="${3:-root}"
    local permissions="${4:-755}"
    
    if [ ! -d "$dir_path" ]; then
        print_info "Creating directory: $dir_path"
        mkdir -p "$dir_path"
        
        if [ $? -eq 0 ]; then
            chown "$owner:$group" "$dir_path"
            chmod "$permissions" "$dir_path"
            print_success "Directory created: $dir_path"
            log_message "SUCCESS" "Directory created: $dir_path (owner: $owner:$group, permissions: $permissions)"
            return 0
        else
            print_error "Failed to create directory: $dir_path"
            log_message "ERROR" "Failed to create directory: $dir_path"
            return 1
        fi
    else
        print_info "Directory already exists: $dir_path"
        return 0
    fi
}

# Function to backup file before modification
backup_file() {
    local file_path="$1"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"
    
    if [ -f "$file_path" ]; then
        local backup_path="${file_path}.backup.$backup_suffix"
        cp "$file_path" "$backup_path"
        
        if [ $? -eq 0 ]; then
            print_info "Backup created: $backup_path"
            log_message "INFO" "Backup created: $file_path -> $backup_path"
            return 0
        else
            print_error "Failed to create backup: $backup_path"
            log_message "ERROR" "Failed to create backup: $file_path -> $backup_path"
            return 1
        fi
    else
        print_warning "File not found for backup: $file_path"
        return 1
    fi
}

# Function to show installation summary
show_summary() {
    local installed_count="$1"
    local failed_count="$2"
    local total_count=$((installed_count + failed_count))
    
    echo ""
    print_info "=== Installation Summary ==="
    echo "  Total components: $total_count"
    echo "  Successfully installed: $installed_count"
    
    if [ $failed_count -gt 0 ]; then
        echo "  Failed installations: $failed_count"
        print_warning "Some components failed to install. Check logs for details."
    else
        print_success "All components installed successfully!"
    fi
    
    echo "  Log file: /var/log/raspberry-config/install.log"
    echo ""
}

# Function to prompt for reboot
prompt_reboot() {
    local interactive="$1"
    local auto_reboot="${2:-true}"
    
    if [ "$auto_reboot" = true ]; then
        if [ "$interactive" = true ]; then
            echo ""
            print_info "Installation completed. The system should be rebooted for all changes to take effect."
            echo -n "Reboot now? [Y/n]: "
            read -r reboot_confirm
            
            if [[ ! "$reboot_confirm" =~ ^[Nn]$ ]]; then
                print_info "Rebooting in 5 seconds... (Press Ctrl+C to cancel)"
                sleep 5
                reboot
            else
                print_info "Reboot cancelled. Please reboot manually when convenient."
            fi
        else
            print_info "Rebooting system..."
            log_message "INFO" "System reboot initiated"
            reboot
        fi
    else
        print_info "Installation completed. Please reboot when convenient."
    fi
}
