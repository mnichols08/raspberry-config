#!/bin/bash

# GPS-specific utility functions
# This file can be sourced by other GPS-related scripts
# 
# Usage: source gps_utils.sh
# 
# Author: Mikey Nichols
# Date: August 2025

# GPS-specific configuration variables
export GPS_DEFAULT_DEVICE="/dev/serial0"
export GPS_DEFAULT_BAUDRATE="9600"
export GPS_CONFIG_DIR="/etc/gps"
export GPS_LOG_DIR="/var/log/gps"

# Function to check if GPS device exists
check_gps_device() {
    local device="${1:-$GPS_DEFAULT_DEVICE}"
    
    if [ -e "$device" ]; then
        echo "✓ GPS device found: $device"
        
        # Check if device is readable
        if [ -r "$device" ]; then
            echo "✓ GPS device is readable"
            return 0
        else
            echo "⚠ GPS device exists but is not readable"
            return 1
        fi
    else
        echo "✗ GPS device not found: $device"
        return 1
    fi
}

# Function to test GPS data stream
test_gps_stream() {
    local device="${1:-$GPS_DEFAULT_DEVICE}"
    local timeout="${2:-10}"
    
    echo "Testing GPS data stream from $device (timeout: ${timeout}s)..."
    
    if ! check_gps_device "$device"; then
        return 1
    fi
    
    echo "Listening for NMEA sentences... (press Ctrl+C to stop)"
    timeout "$timeout" cat "$device" | head -10
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "✓ GPS data stream test successful"
        return 0
    elif [ $exit_code -eq 124 ]; then
        echo "⚠ GPS test timed out after ${timeout}s - no data received"
        return 1
    else
        echo "✗ GPS test failed with exit code: $exit_code"
        return 1
    fi
}

# Function to check GPSD status
check_gpsd_status() {
    echo "=== GPSD Status Check ==="
    
    # Check if GPSD is installed
    if command -v gpsd >/dev/null 2>&1; then
        echo "✓ GPSD is installed"
        gpsd -V | head -1
    else
        echo "✗ GPSD is not installed"
        return 1
    fi
    
    # Check service status
    if systemctl is-active --quiet gpsd; then
        echo "✓ GPSD service is running"
    else
        echo "⚠ GPSD service is not running"
    fi
    
    if systemctl is-enabled --quiet gpsd; then
        echo "✓ GPSD service is enabled"
    else
        echo "⚠ GPSD service is not enabled"
    fi
    
    # Check listening ports
    if netstat -an 2>/dev/null | grep -q ":2947"; then
        echo "✓ GPSD is listening on port 2947"
    else
        echo "⚠ GPSD is not listening on port 2947"
    fi
    
    echo
}

# Function to configure GPSD daemon
configure_gpsd_daemon() {
    local device="${1:-$GPS_DEFAULT_DEVICE}"
    local options="${2:--n}"
    
    echo "Configuring GPSD daemon..."
    echo "Device: $device"
    echo "Options: $options"
    
    # Create GPSD configuration
    cat > /etc/default/gpsd << EOF
# Default settings for the gpsd init script and the hotplug wrapper.

# Start the gpsd daemon automatically at boot time
START_DAEMON="true"

# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"

# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="$device"

# Other options you want to pass to gpsd
GPSD_OPTIONS="$options"
EOF

    if [ $? -eq 0 ]; then
        echo "✓ GPSD configuration updated: /etc/default/gpsd"
        
        # Restart and enable service
        systemctl restart gpsd
        systemctl enable gpsd
        
        echo "✓ GPSD service restarted and enabled"
        
        # Wait a moment for service to start
        sleep 3
        
        # Check status
        check_gpsd_status
        
        return 0
    else
        echo "✗ Failed to configure GPSD"
        return 1
    fi
}

# Function to create GPS log directory
setup_gps_logging() {
    local log_dir="${1:-$GPS_LOG_DIR}"
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        chmod 755 "$log_dir"
        echo "✓ Created GPS log directory: $log_dir"
    else
        echo "✓ GPS log directory exists: $log_dir"
    fi
    
    # Create a simple log rotation config
    cat > /etc/logrotate.d/gps << EOF
$log_dir/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
}
EOF
    
    echo "✓ GPS log rotation configured"
}

# Function to run GPS diagnostics
gps_diagnostics() {
    echo "=== GPS System Diagnostics ==="
    echo
    
    echo "1. Hardware Check:"
    check_gps_device
    echo
    
    echo "2. Software Check:"
    check_gpsd_status
    echo
    
    echo "3. Serial Port Status:"
    if [ -L /dev/serial0 ]; then
        ls -l /dev/serial0
    else
        echo "⚠ /dev/serial0 symlink not found"
    fi
    echo
    
    echo "4. Configuration Files:"
    if [ -f /etc/default/gpsd ]; then
        echo "✓ GPSD config exists: /etc/default/gpsd"
        grep -E "^(START_DAEMON|DEVICES|GPSD_OPTIONS)" /etc/default/gpsd | sed 's/^/  /'
    else
        echo "⚠ GPSD config not found: /etc/default/gpsd"
    fi
    echo
    
    echo "5. Process Check:"
    if pgrep -f gpsd >/dev/null; then
        echo "✓ GPSD process is running:"
        ps aux | grep [g]psd | sed 's/^/  /'
    else
        echo "⚠ GPSD process not found"
    fi
    echo
    
    echo "6. Quick Data Test (5 seconds):"
    test_gps_stream "$GPS_DEFAULT_DEVICE" 5
    echo
}

# Export functions so they're available to scripts that source this file
export -f check_gps_device
export -f test_gps_stream
export -f check_gpsd_status
export -f configure_gpsd_daemon
export -f setup_gps_logging
export -f gps_diagnostics

# If script is run directly (not sourced), show help
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "GPS Utilities Script"
    echo ""
    echo "This script provides GPS-related utility functions."
    echo "It's designed to be sourced by other scripts:"
    echo ""
    echo "  source gps_utils.sh"
    echo ""
    echo "Available functions:"
    echo "  - check_gps_device [device]"
    echo "  - test_gps_stream [device] [timeout]"
    echo "  - check_gpsd_status"
    echo "  - configure_gpsd_daemon [device] [options]"
    echo "  - setup_gps_logging [log_dir]"
    echo "  - gps_diagnostics"
    echo ""
    echo "Available variables:"
    echo "  - GPS_DEFAULT_DEVICE: $GPS_DEFAULT_DEVICE"
    echo "  - GPS_DEFAULT_BAUDRATE: $GPS_DEFAULT_BAUDRATE"
    echo "  - GPS_CONFIG_DIR: $GPS_CONFIG_DIR"
    echo "  - GPS_LOG_DIR: $GPS_LOG_DIR"
    echo ""
    echo "Example usage:"
    echo "  source gps_utils.sh"
    echo "  gps_diagnostics"
fi
