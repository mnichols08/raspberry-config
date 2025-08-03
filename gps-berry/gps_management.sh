#!/bin/bash

# Example GPS Management Script
# Demonstrates how to use shared utilities and configuration
# 
# This script shows best practices for:
# - Loading shared utilities
# - Using configuration files
# - Exporting functions for other scripts
# - Error handling and logging
#
# Author: Mikey Nichols
# Date: August 2025

# === Load Shared Components ===

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define paths to shared components
UTILS_PATH="$SCRIPT_DIR/../essentials/utils.sh"
GPS_UTILS_PATH="$SCRIPT_DIR/gps_utils.sh"
CONFIG_PATH="$SCRIPT_DIR/gpsberry.conf"

# Load utilities with error checking
load_shared_utilities() {
    local loaded_count=0
    
    # Load general utilities
    if [ -f "$UTILS_PATH" ]; then
        source "$UTILS_PATH"
        echo "✓ Loaded general utilities"
        ((loaded_count++))
    else
        echo "⚠ Warning: General utilities not found at: $UTILS_PATH"
    fi
    
    # Load GPS-specific utilities
    if [ -f "$GPS_UTILS_PATH" ]; then
        source "$GPS_UTILS_PATH"
        echo "✓ Loaded GPS utilities"
        ((loaded_count++))
    else
        echo "⚠ Warning: GPS utilities not found at: $GPS_UTILS_PATH"
    fi
    
    # Load configuration if available
    if [ -f "$CONFIG_PATH" ] && command -v load_config >/dev/null 2>&1; then
        load_config "$CONFIG_PATH"
        echo "✓ Loaded configuration from: $CONFIG_PATH"
        ((loaded_count++))
    else
        echo "⚠ Warning: Configuration not loaded"
    fi
    
    echo "Loaded $loaded_count shared components"
    return 0
}

# === Fallback Functions ===
# These provide basic functionality if shared utilities aren't available

setup_fallbacks() {
    # Basic logging if not available
    if ! command -v log_message >/dev/null 2>&1; then
        log_message() {
            local level=$1
            shift
            local message="$@"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >&2
        }
    fi
    
    # Basic print functions if not available
    if ! command -v print_info >/dev/null 2>&1; then
        print_info() { echo "ℹ  $@"; }
        print_success() { echo "✓ $@"; }
        print_warning() { echo "⚠  $@"; }
        print_error() { echo "✗ $@"; }
    fi
}

# === Main Functions ===

# Function to show current configuration
show_config() {
    echo "=== Current Configuration ==="
    echo
    
    # Show GPS device settings
    echo "GPS Device: ${CONFIG_GPS_DEVICE:-${GPS_DEFAULT_DEVICE:-/dev/serial0}}"
    echo "Baud Rate: ${CONFIG_GPS_BAUDRATE:-${GPS_DEFAULT_BAUDRATE:-9600}}"
    echo "Timeout: ${CONFIG_GPS_TIMEOUT:-${TEST_TIMEOUT:-10}}s"
    echo
    
    # Show GPSD settings
    echo "GPSD Enabled: ${CONFIG_GPSD_ENABLED:-true}"
    echo "GPSD Options: ${CONFIG_GPSD_OPTIONS:--n}"
    echo "GPSD Port: ${CONFIG_GPSD_PORT:-2947}"
    echo
    
    # Show logging settings
    echo "Log File: ${CONFIG_LOG_FILE:-/var/log/gps/gpsberry.log}"
    echo "Log Level: ${CONFIG_LOG_LEVEL:-INFO}"
    echo
}

# Function to run comprehensive GPS check
run_gps_check() {
    print_info "Running comprehensive GPS check..."
    
    # Use GPS diagnostics function if available
    if command -v gps_diagnostics >/dev/null 2>&1; then
        gps_diagnostics
    else
        print_warning "GPS diagnostics not available - using basic checks"
        
        # Basic device check
        local device="${CONFIG_GPS_DEVICE:-${GPS_DEFAULT_DEVICE:-/dev/serial0}}"
        if [ -e "$device" ]; then
            print_success "GPS device exists: $device"
        else
            print_error "GPS device not found: $device"
            return 1
        fi
        
        # Basic GPSD check
        if systemctl is-active --quiet gpsd; then
            print_success "GPSD service is running"
        else
            print_warning "GPSD service is not running"
        fi
    fi
}

# Function to install missing GPS tools
install_gps_tools() {
    print_info "Installing GPS tools..."
    
    local packages="gpsd gpsd-clients minicom screen"
    
    # Use shared install function if available
    if command -v install_packages >/dev/null 2>&1; then
        install_packages $packages
    else
        print_info "Using basic package installation..."
        apt update && apt install -y $packages
    fi
}

# Function to setup GPS logging
setup_logging() {
    local log_dir="${CONFIG_LOG_DIR:-/var/log/gps}"
    
    print_info "Setting up GPS logging..."
    
    # Use shared function if available
    if command -v setup_gps_logging >/dev/null 2>&1; then
        setup_gps_logging "$log_dir"
    else
        print_info "Using basic logging setup..."
        mkdir -p "$log_dir"
        chmod 755 "$log_dir"
        print_success "Created log directory: $log_dir"
    fi
}

# Function to show usage information
show_usage() {
    echo "GPS Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  check       Run GPS system diagnostics"
    echo "  config      Show current configuration"
    echo "  install     Install GPS tools and dependencies"
    echo "  setup       Setup GPS logging and directories"
    echo "  test        Test GPS data stream"
    echo "  status      Show GPS and GPSD status"
    echo ""
    echo "Options:"
    echo "  -h, --help  Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 check                # Run diagnostics"
    echo "  $0 install              # Install GPS tools"
    echo "  $0 config               # Show configuration"
    echo "  $0 test                 # Test GPS stream"
}

# === Main Script Logic ===

main() {
    # Setup fallback functions first
    setup_fallbacks
    
    # Load shared utilities
    echo "Loading shared components..."
    load_shared_utilities
    echo
    
    # Parse command line arguments
    local command="$1"
    
    case "$command" in
        "check"|"c")
            run_gps_check
            ;;
        "config"|"cfg")
            show_config
            ;;
        "install"|"i")
            install_gps_tools
            ;;
        "setup"|"s")
            setup_logging
            ;;
        "test"|"t")
            if command -v test_gps_stream >/dev/null 2>&1; then
                test_gps_stream
            else
                print_error "GPS test function not available"
                return 1
            fi
            ;;
        "status"|"st")
            if command -v check_gpsd_status >/dev/null 2>&1; then
                check_gpsd_status
            else
                print_error "GPS status function not available"
                return 1
            fi
            ;;
        "help"|"h"|"-h"|"--help"|"")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo
            show_usage
            return 1
            ;;
    esac
}

# === Export Functions for Other Scripts ===

# Export utility functions so other scripts can source this file
export -f load_shared_utilities
export -f show_config
export -f run_gps_check
export -f install_gps_tools
export -f setup_logging

# Export configuration paths
export GPS_MANAGEMENT_UTILS_PATH="$GPS_UTILS_PATH"
export GPS_MANAGEMENT_CONFIG_PATH="$CONFIG_PATH"

# Run main function if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    # Script is being sourced
    echo "GPS management utilities loaded. Available functions:"
    echo "  - load_shared_utilities"
    echo "  - show_config"
    echo "  - run_gps_check"
    echo "  - install_gps_tools"
    echo "  - setup_logging"
fi
