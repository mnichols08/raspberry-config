#!/bin/bash

# GPS Serial Communication Setup and Testing Script
# Enhanced version with improved user interaction and automation support
# This script provides multiple ways to test GPS communication via serial
# on a Raspberry Pi.
# It is designed to be run after the GPSBerry installation script.
# Usage: Run this script as root or with sudo privileges.
# Author: Mikey Nichols

# Import shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="$SCRIPT_DIR/../essentials/utils.sh"
GPS_UTILS_PATH="$SCRIPT_DIR/gps_utils.sh"

# Load shared utilities if available
if [ -f "$UTILS_PATH" ]; then
    source "$UTILS_PATH"
    echo "✓ Loaded shared utilities from: $UTILS_PATH"
fi

# Load GPS-specific utilities if available
if [ -f "$GPS_UTILS_PATH" ]; then
    source "$GPS_UTILS_PATH"
    echo "✓ Loaded GPS utilities from: $GPS_UTILS_PATH"
fi

# Fallback color codes for better visual feedback (if utils.sh not loaded)
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
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

# Global variables
INTERACTIVE=true
DRY_RUN=false
LOG_FILE="/tmp/gps-test.log"
SERIAL_DEVICE="/dev/serial0"
BAUD_RATE=9600
TEST_TIMEOUT=10
AUTO_METHOD=""
INSTALL_TOOLS=false
VERBOSE=false

# Function to display usage information
show_usage() {
    echo "GPS Serial Communication Test Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --non-interactive   Run in non-interactive mode"
    echo "  -d, --dry-run           Show what would be done without making changes"
    echo "  -l, --log FILE          Specify custom log file (default: $LOG_FILE)"
    echo "  -v, --verbose           Enable verbose output"
    echo ""
    echo "GPS Testing Options:"
    echo "  -m, --method METHOD     Auto-select test method:"
    echo "                            cat, minicom, screen, install-only, skip"
    echo "  -t, --timeout SECONDS   Test timeout in seconds (default: $TEST_TIMEOUT)"
    echo "  -b, --baud RATE         Baud rate (default: $BAUD_RATE)"
    echo "  -s, --serial DEVICE     Serial device (default: $SERIAL_DEVICE)"
    echo "  -i, --install-tools     Install testing tools (minicom, screen)"
    echo "  --gpsd                  Test GPSD daemon instead of raw serial"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 --method cat --timeout 30         # Quick test for 30 seconds"
    echo "  $0 --non-interactive --install-tools # Install tools only"
    echo "  $0 --method minicom --baud 4800      # Use minicom with custom baud"
    echo "  $0 --dry-run --method screen         # Preview screen test"
    echo "  $0 --gpsd --verbose                  # Test GPSD daemon"
}

# Function to log messages
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to print status messages
print_status() {
    print_color $BLUE "ℹ  $@"
    log_message "INFO" "$@"
}

print_success() {
    print_color $GREEN "✓ $@"
    log_message "SUCCESS" "$@"
}

print_warning() {
    print_color $YELLOW "⚠  $@"
    log_message "WARNING" "$@"
}

print_error() {
    print_color $RED "✗ $@"
    log_message "ERROR" "$@"
}

print_debug() {
    if [ "$VERBOSE" = true ]; then
        print_color $PURPLE "🔍 $@"
        log_message "DEBUG" "$@"
    fi
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

# Function to show a menu and get selection
show_menu() {
    if [ "$INTERACTIVE" = false ] && [ -n "$AUTO_METHOD" ]; then
        print_status "Non-interactive mode: using method '$AUTO_METHOD'"
        case $AUTO_METHOD in
            cat) return 1 ;;
            minicom) return 2 ;;
            screen) return 3 ;;
            install-only) return 4 ;;
            skip) return 5 ;;
            gpsd) return 6 ;;
            *) 
                print_error "Invalid method: $AUTO_METHOD"
                exit 1
                ;;
        esac
    fi
    
    echo
    print_color $CYAN "Choose a method to test GPS communication:"
    echo "1) Quick test with cat (Ctrl+C to exit)"
    echo "2) Install and use Minicom (interactive)"
    echo "3) Install and use Screen (interactive)"
    echo "4) Install tools only (for future use)"
    echo "5) Skip testing"
    echo "6) Test GPSD daemon"
    
    while true; do
        read -p "Enter choice (1-6): " choice
        case $choice in
            [1-6]) return $choice ;;
            *) print_warning "Please enter a number between 1 and 6." ;;
        esac
    done
}

# Function to check system prerequisites
check_prerequisites() {
    print_status "Checking GPS system prerequisites..."
    
    local all_good=true
    
    # Check UART configuration
    print_debug "Checking UART configuration in /boot/config.txt"
    if grep -q "enable_uart=1" /boot/config.txt 2>/dev/null; then
        print_success "UART is enabled in /boot/config.txt"
    else
        print_warning "UART may not be enabled in /boot/config.txt"
        print_status "You may need to run: sudo raspi-config nonint do_serial 2"
        all_good=false
    fi
    
    # Check serial console
    print_debug "Checking serial console configuration"
    if grep -q "console=serial" /boot/cmdline.txt 2>/dev/null; then
        print_warning "Serial console may be enabled (could interfere with GPS)"
        print_status "Consider running: sudo raspi-config nonint do_serial 2"
    else
        print_success "Serial console appears to be disabled"
    fi
    
    # Check serial device
    print_debug "Checking serial device: $SERIAL_DEVICE"
    if [ -e "$SERIAL_DEVICE" ]; then
        print_success "Serial device $SERIAL_DEVICE found"
        
        # Show device permissions
        local perms=$(ls -l "$SERIAL_DEVICE" 2>/dev/null)
        print_debug "Device permissions: $perms"
        
        # Check if device is accessible
        if [ -r "$SERIAL_DEVICE" ] && [ -w "$SERIAL_DEVICE" ]; then
            print_success "Device is readable and writable"
        else
            print_warning "Device may not be accessible (permissions issue)"
        fi
        
        # Show what the device links to
        if [ -L "$SERIAL_DEVICE" ]; then
            local target=$(readlink "$SERIAL_DEVICE")
            print_debug "Device links to: $target"
        fi
    else
        print_error "Serial device $SERIAL_DEVICE not found"
        print_status "Available serial devices:"
        ls -la /dev/serial* 2>/dev/null | sed 's/^/  /' || echo "  No serial devices found"
        ls -la /dev/ttyS* /dev/ttyAMA* 2>/dev/null | head -5 | sed 's/^/  /'
        all_good=false
    fi
    
    # Check for GPS-related processes
    print_debug "Checking for running GPS processes"
    if pgrep -f "gpsd" >/dev/null; then
        print_status "GPSD daemon is running"
        print_debug "GPSD processes: $(pgrep -f gpsd | tr '\n' ' ')"
    else
        print_status "GPSD daemon is not running"
    fi
    
    # Check for conflicting processes using serial port
    local serial_procs=$(lsof "$SERIAL_DEVICE" 2>/dev/null | grep -v COMMAND)
    if [ -n "$serial_procs" ]; then
        print_warning "Processes using $SERIAL_DEVICE:"
        echo "$serial_procs" | sed 's/^/  /'
    fi
    
    # Show system info
    if [ "$VERBOSE" = true ]; then
        print_debug "System information:"
        print_debug "  Kernel: $(uname -r)"
        print_debug "  Pi model: $(grep Model /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'Unknown')"
        print_debug "  Uptime: $(uptime -p)"
    fi
    
    echo
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# Function to install tools with error handling
install_tools() {
    local tools="$1"
    print_status "Installing GPS testing tools: $tools"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would install: $tools"
        return 0
    fi
    
    # Update package list if not done recently
    local last_update=$(stat -c %Y /var/lib/apt/lists 2>/dev/null | head -1)
    local current_time=$(date +%s)
    local age=$((current_time - last_update))
    
    if [ $age -gt 3600 ]; then  # 1 hour
        print_status "Updating package lists (last update was $((age/60)) minutes ago)..."
        sudo apt-get update
    fi
    
    if sudo apt-get install $tools -y; then
        print_success "Tools installed successfully"
        
        # Verify installation
        for tool in $tools; do
            if command -v $tool >/dev/null 2>&1; then
                local version=$(dpkg -l | grep "^ii.*$tool " | awk '{print $3}' | head -1)
                print_debug "$tool version: $version"
            fi
        done
    else
        print_error "Failed to install tools: $tools"
        return 1
    fi
}

# Function to test with cat
test_with_cat() {
    print_status "Testing GPS with cat command..."
    print_status "Device: $SERIAL_DEVICE, Timeout: ${TEST_TIMEOUT}s"
    print_status "You should see NMEA sentences if GPS is working..."
    print_warning "Press Ctrl+C to stop early"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would run 'timeout $TEST_TIMEOUT cat $SERIAL_DEVICE'"
        return 0
    fi
    
    echo
    print_color $CYAN "--- GPS Data Output (${TEST_TIMEOUT}s timeout) ---"
    
    # Use timeout with cat and capture exit code
    local data_received=false
    local line_count=0
    
    timeout "$TEST_TIMEOUT" cat "$SERIAL_DEVICE" | while IFS= read -r line; do
        echo "$line"
        line_count=$((line_count + 1))
        data_received=true
        
        # Log first few lines for debugging
        if [ $line_count -le 5 ]; then
            log_message "GPS_DATA" "$line"
        fi
    done
    
    local exit_code=${PIPESTATUS[0]}
    
    print_color $CYAN "--- End GPS Data ---"
    echo
    
    if [ $exit_code -eq 124 ]; then
        print_status "Test completed (timeout reached)"
    elif [ $exit_code -eq 0 ]; then
        print_status "Data stream ended normally"
    else
        print_warning "Unexpected exit code: $exit_code"
    fi
}

# Function to test with minicom
test_with_minicom() {
    print_status "Setting up Minicom for GPS testing..."
    
    if ! command -v minicom >/dev/null 2>&1; then
        print_status "Minicom not found, installing..."
        install_tools "minicom" || return 1
    fi
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would start minicom with: sudo minicom -b $BAUD_RATE -o -D $SERIAL_DEVICE"
        return 0
    fi
    
    print_status "Starting Minicom..."
    print_status "GPS should output NMEA sentences at $BAUD_RATE baud"
    echo
    print_color $YELLOW "Minicom commands:"
    echo "  Exit: Ctrl+A then q"
    echo "  Help: Ctrl+A then z"
    echo "  Settings: Ctrl+A then o"
    echo "  Clear screen: Ctrl+A then c"
    echo
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Press Enter to start Minicom (or Ctrl+C to cancel)..."
    else
        print_status "Starting Minicom in 3 seconds..."
        sleep 3
    fi
    
    print_status "Launching: sudo minicom -b $BAUD_RATE -o -D $SERIAL_DEVICE"
    sudo minicom -b "$BAUD_RATE" -o -D "$SERIAL_DEVICE"
}

# Function to test with screen
test_with_screen() {
    print_status "Setting up Screen for GPS testing..."
    
    if ! command -v screen >/dev/null 2>&1; then
        print_status "Screen not found, installing..."
        install_tools "screen" || return 1
    fi
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would start screen with: screen $SERIAL_DEVICE $BAUD_RATE"
        return 0
    fi
    
    print_status "Starting Screen..."
    print_status "GPS should output NMEA sentences at $BAUD_RATE baud"
    echo
    print_color $YELLOW "Screen commands:"
    echo "  Exit: Ctrl+A then k, then y"
    echo "  Detach: Ctrl+A then d (leaves session running)"
    echo "  Help: Ctrl+A then ?"
    echo "  Clear: Ctrl+L"
    echo
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Press Enter to start Screen (or Ctrl+C to cancel)..."
    else
        print_status "Starting Screen in 3 seconds..."
        sleep 3
    fi
    
    print_status "Launching: screen $SERIAL_DEVICE $BAUD_RATE"
    screen "$SERIAL_DEVICE" "$BAUD_RATE"
}

# Function to test GPSD daemon
test_gpsd() {
    print_status "Testing GPSD daemon..."
    
    # Check if GPSD is installed
    if ! command -v gpsd >/dev/null 2>&1; then
        print_error "GPSD not installed. Please run the GPSBerry installation script first."
        return 1
    fi
    
    # Check if GPSD is running
    if ! pgrep -f "gpsd" >/dev/null; then
        print_warning "GPSD daemon is not running"
        if ask_yes_no "Start GPSD daemon?" "y"; then
            if $DRY_RUN; then
                print_status "DRY RUN: Would start GPSD"
            else
                print_status "Starting GPSD daemon..."
                sudo systemctl start gpsd
                sleep 2
            fi
        else
            return 1
        fi
    else
        print_success "GPSD daemon is running"
    fi
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would test GPSD with various client tools"
        return 0
    fi
    
    # Test with gpsmon if available
    if command -v gpsmon >/dev/null 2>&1; then
        print_status "Testing with gpsmon..."
        echo
        print_color $YELLOW "gpsmon commands:"
        echo "  Exit: q"
        echo "  Help: ?"
        echo
        if [ "$INTERACTIVE" = true ]; then
            read -p "Press Enter to start gpsmon..."
        fi
        gpsmon
    else
        # Test with gpspipe
        if command -v gpspipe >/dev/null 2>&1; then
            print_status "Testing with gpspipe for ${TEST_TIMEOUT}s..."
            timeout "$TEST_TIMEOUT" gpspipe -r
        else
            print_warning "No GPSD client tools found"
            print_status "Install with: sudo apt-get install gpsd-clients"
        fi
    fi
}

# Function to show comprehensive test results
show_test_summary() {
    print_color $CYAN "=================================================="
    print_color $CYAN "              GPS Test Summary"
    print_color $CYAN "=================================================="
    echo
    
    print_color $BLUE "📋 Test Configuration:"
    echo "  Serial Device: $SERIAL_DEVICE"
    echo "  Baud Rate: $BAUD_RATE"
    echo "  Test Timeout: ${TEST_TIMEOUT}s"
    echo "  Log File: $LOG_FILE"
    echo
    
    print_color $YELLOW "🔍 Troubleshooting Tips:"
    echo "If no GPS data was received, check:"
    echo "  • GPS antenna connection and placement"
    echo "  • Power supply to GPS module (usually 3.3V or 5V)"
    echo "  • Serial wiring connections (TX→RX, RX→TX, GND→GND)"
    echo "  • Baud rate configuration (try: 4800, 9600, 38400)"
    echo "  • GPS module compatibility and startup time"
    echo "  • Interference from other devices"
    echo
    
    print_color $GREEN "📡 Expected NMEA Output Examples:"
    echo '  $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47'
    echo '  $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A'
    echo '  $GPGSV,2,1,08,01,40,083,46,02,17,308,41,12,07,344,39,14,22,228,45*75'
    echo
    
    print_color $CYAN "🛠  Useful Commands for Later:"
    echo "  Quick test: cat $SERIAL_DEVICE"
    echo "  Minicom: sudo minicom -b $BAUD_RATE -o -D $SERIAL_DEVICE"
    echo "  Screen: screen $SERIAL_DEVICE $BAUD_RATE"
    if command -v gpspipe >/dev/null 2>&1; then
        echo "  GPSD test: gpspipe -r"
    fi
    echo
}

# Function to handle cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "GPS test failed with exit code $exit_code"
        print_status "Check log file for details: $LOG_FILE"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Parse command line arguments
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
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -m|--method)
            AUTO_METHOD="$2"
            shift 2
            ;;
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        -b|--baud)
            BAUD_RATE="$2"
            shift 2
            ;;
        -s|--serial)
            SERIAL_DEVICE="$2"
            shift 2
            ;;
        -i|--install-tools)
            INSTALL_TOOLS=true
            shift
            ;;
        --gpsd)
            AUTO_METHOD="gpsd"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate numeric parameters
if ! [[ "$TEST_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TEST_TIMEOUT" -lt 1 ]; then
    print_error "Invalid timeout: $TEST_TIMEOUT (must be positive integer)"
    exit 1
fi

if ! [[ "$BAUD_RATE" =~ ^[0-9]+$ ]] || [ "$BAUD_RATE" -lt 300 ]; then
    print_error "Invalid baud rate: $BAUD_RATE (must be >= 300)"
    exit 1
fi

# Main function
main() {
    # Initialize log file
    echo "GPS Test Log - $(date)" > "$LOG_FILE"
    
    # Show script header
    print_color $CYAN "=================================================="
    print_color $CYAN "       GPS Serial Communication Test"
    print_color $CYAN "=================================================="
    echo
    
    if [ "$INTERACTIVE" = false ]; then
        print_status "Running in NON-INTERACTIVE mode"
    fi
    
    if $DRY_RUN; then
        print_warning "DRY RUN mode - no changes will be made"
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Handle install-tools flag
    if [ "$INSTALL_TOOLS" = true ]; then
        install_tools "minicom screen"
        if [ "$INTERACTIVE" = false ]; then
            print_status "Tools installation complete"
            show_test_summary
            exit 0
        fi
    fi
    
    # Show menu and get user choice
    show_menu
    choice=$?
    
    echo
    print_status "Selected test method: $choice"
    
    case $choice in
        1)
            test_with_cat
            ;;
        2)
            test_with_minicom
            ;;
        3)
            test_with_screen
            ;;
        4)
            install_tools "minicom screen"
            print_success "Tools installed successfully!"
            ;;
        5)
            print_status "Skipping GPS testing..."
            ;;
        6)
            test_gpsd
            ;;
        *)
            print_error "Invalid choice. Skipping GPS testing..."
            ;;
    esac
    
    echo
    show_test_summary
}

# Check if running as root/sudo for operations that need it
if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
    print_warning "Some operations may require root privileges"
    print_status "Consider running with: sudo $0 $*"
fi

# Run main function
main "$@"