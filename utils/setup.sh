#!/bin/bash

# Raspberry Pi Configuration Setup Script
# Handles utilities loading, configuration, and repository cloning
# 
# Author: Mikey Nichols

# Default values
DEFAULT_GIT_URL="https://github.com/mnichols08/raspberry-config"
DEFAULT_TEMP_DIR="/var/tmp"
DEFAULT_CONFIG_FILE="./etc/pi-config.conf"
CLONE_DIR_NAME="raspberry-config"

# Initialize variables
INTERACTIVE_MODE=true
GIT_URL=""
TEMP_DIR=""
CONFIG_FILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Raspberry Pi Configuration Setup Script"
    echo "Loads utilities, configuration, and clones the repository"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --non-interactive   Run in non-interactive mode"
    echo "  -u, --git-url URL       Git repository URL to clone from"
    echo "  -t, --temp-dir DIR      Temporary directory for cloning (default: /var/tmp)"
    echo "  -c, --config FILE       Configuration file path (default: ./etc/pi-config.conf)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode with defaults"
    echo "  $0 -n                                 # Non-interactive mode"
    echo "  $0 -u https://github.com/user/repo    # Custom git repository"
    echo "  $0 -t /tmp -n                         # Custom temp dir, non-interactive"
    echo ""
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--non-interactive)
                INTERACTIVE_MODE=false
                shift
                ;;
            -u|--git-url)
                GIT_URL="$2"
                shift 2
                ;;
            -t|--temp-dir)
                TEMP_DIR="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Load utilities from essentials/utils.sh
load_utilities() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local utils_file="$script_dir/essentials/utils.sh"
    
    if [ -f "$utils_file" ]; then
        echo "Loading utilities from: $utils_file"
        source "$utils_file"
        print_success "Utilities loaded successfully"
    else
        echo "ERROR: Utils file not found at: $utils_file"
        echo "Please ensure essentials/utils.sh exists in the same directory as this script"
        exit 1
    fi
}

# Load configuration file and set environment variables
load_configuration() {
    local config_file="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
    
    if [ -f "$config_file" ]; then
        print_info "Loading configuration from: $config_file"
        load_config "$config_file"
        
        # Set variables from config if not already set by command line
        if [ -z "$TEMP_DIR" ] && [ -n "$CONFIG_temp_dir" ]; then
            TEMP_DIR="$CONFIG_temp_dir"
        fi
        
        if [ -z "$GIT_URL" ] && [ -n "$CONFIG_git_url" ]; then
            GIT_URL="$CONFIG_git_url"
        fi
    else
        print_info "Configuration file not found: $config_file"
        print_info "Using default values"
    fi
    
    # Set defaults if still empty
    TEMP_DIR="${TEMP_DIR:-$DEFAULT_TEMP_DIR}"
    GIT_URL="${GIT_URL:-$DEFAULT_GIT_URL}"
    
    # Export temp_dir as environment variable as requested
    export temp_dir="$TEMP_DIR"
}

# Interactive prompts for configuration
interactive_setup() {
    if [ "$INTERACTIVE_MODE" = true ]; then
        print_info "=== Interactive Setup ==="
        
        # Prompt for git URL
        echo ""
        print_info "Current Git URL: $GIT_URL"
        echo -n "Enter Git URL (or press Enter to use current): "
        read -r user_git_url
        if [ -n "$user_git_url" ]; then
            GIT_URL="$user_git_url"
        fi
        
        # Prompt for temp directory
        echo ""
        print_info "Current temporary directory: $TEMP_DIR"
        echo -n "Enter temporary directory (or press Enter to use current): "
        read -r user_temp_dir
        if [ -n "$user_temp_dir" ]; then
            TEMP_DIR="$user_temp_dir"
            export temp_dir="$TEMP_DIR"
        fi
        
        # Show final configuration
        echo ""
        print_info "=== Final Configuration ==="
        echo "  Git URL: $GIT_URL"
        echo "  Temp directory: $TEMP_DIR"
        echo "  Clone path: $TEMP_DIR/$CLONE_DIR_NAME"
        echo ""
        
        echo -n "Proceed with setup? [Y/n]: "
        read -r proceed_confirm
        if [[ "$proceed_confirm" =~ ^[Nn]$ ]]; then
            print_info "Setup cancelled by user"
            exit 0
        fi
    fi
}

# Check and handle existing repository directory
check_existing_repo() {
    local clone_path="$TEMP_DIR/$CLONE_DIR_NAME"
    
    if [ -d "$clone_path" ]; then
        print_warning "Existing directory found: $clone_path"
        
        if [ "$INTERACTIVE_MODE" = true ]; then
            echo -n "Remove existing directory? [Y/n]: "
            read -r remove_confirm
            if [[ "$remove_confirm" =~ ^[Nn]$ ]]; then
                print_error "Cannot proceed with existing directory"
                exit 1
            fi
        fi
        
        print_info "Removing existing directory: $clone_path"
        rm -rf "$clone_path"
        
        if [ $? -eq 0 ]; then
            print_success "Existing directory removed"
        else
            print_error "Failed to remove existing directory"
            exit 1
        fi
    fi
}

# Clone the repository
clone_repository() {
    local clone_path="$TEMP_DIR/$CLONE_DIR_NAME"
    
    print_info "Cloning repository..."
    print_info "  Source: $GIT_URL"
    print_info "  Target: $clone_path"
    
    # Create temp directory if it doesn't exist
    if [ ! -d "$TEMP_DIR" ]; then
        print_info "Creating temporary directory: $TEMP_DIR"
        mkdir -p "$TEMP_DIR"
        if [ $? -ne 0 ]; then
            print_error "Failed to create temporary directory: $TEMP_DIR"
            exit 1
        fi
    fi
    
    # Clone the repository
    git clone "$GIT_URL" "$clone_path"
    
    if [ $? -eq 0 ]; then
        print_success "Repository cloned successfully"
        
        # Make scripts executable
        find "$clone_path" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
        print_info "Made shell scripts executable"
        
        # Export the clone path for use by other scripts
        export RASPBERRY_CONFIG_PATH="$clone_path"
        
        return 0
    else
        print_error "Failed to clone repository"
        return 1
    fi
}

# Main setup process
main() {
    echo "=== Raspberry Pi Configuration Setup ==="
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load utilities first
    load_utilities
    
    # Load configuration and set environment variables
    load_configuration
    
    # Interactive setup if needed
    interactive_setup
    
    # Log the start of setup
    log_message "INFO" "Starting setup with Git URL: $GIT_URL, Temp Dir: $TEMP_DIR"
    
    # Check for existing repository and handle it
    check_existing_repo
    
    # Clone the repository
    if clone_repository; then
        print_success "Setup completed successfully"
        print_info "Repository available at: $TEMP_DIR/$CLONE_DIR_NAME"
        print_info "Environment variable 'temp_dir' set to: $temp_dir"
        
        log_message "SUCCESS" "Setup completed successfully"
        
        # Show what's available in the cloned repository
        local clone_path="$TEMP_DIR/$CLONE_DIR_NAME"
        if [ -d "$clone_path" ]; then
            echo ""
            print_info "Available components:"
            if [ -d "$clone_path/essentials" ]; then
                echo "  - essentials/     (Essential packages and utilities)"
            fi
            if [ -d "$clone_path/init" ]; then
                echo "  - init/           (Initial system configuration)"
            fi
            if [ -d "$clone_path/theme" ]; then
                echo "  - theme/          (Custom theme and splash screen)"
            fi
            if [ -d "$clone_path/x735" ]; then
                echo "  - x735/           (X735 power management board)"
            fi
            if [ -d "$clone_path/gps-berry" ]; then
                echo "  - gps-berry/      (GPS functionality)"
            fi
            if [ -d "$clone_path/git-loader" ]; then
                echo "  - git-loader/     (Git repository management)"
            fi
        fi
        
    else
        print_error "Setup failed"
        log_message "ERROR" "Setup failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
