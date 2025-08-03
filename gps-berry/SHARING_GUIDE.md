# Bash Script Sharing and Importing Guide

This document explains how to share functions, variables, and configurations between bash scripts in the raspberry-config project.

## Table of Contents
1. [Importing/Sourcing Scripts](#importing-sourcing-scripts)
2. [Exporting Functions and Variables](#exporting-functions-and-variables)
3. [Configuration Files](#configuration-files)
4. [Best Practices](#best-practices)
5. [Examples](#examples)

## Importing/Sourcing Scripts

### Basic Sourcing
Use `source` or `.` to import functions and variables from another script:

```bash
# Method 1: Using source command
source /path/to/script.sh

# Method 2: Using dot notation (equivalent)
. /path/to/script.sh

# Method 3: Relative path sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../essentials/utils.sh"
```

### Safe Sourcing with Error Checking
```bash
# Check if file exists before sourcing
if [ -f "/path/to/utils.sh" ]; then
    source "/path/to/utils.sh"
    echo "✓ Loaded utilities"
else
    echo "⚠ Warning: Utilities not found"
fi
```

### Example: Loading Shared Utilities
```bash
#!/bin/bash

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
```

## Exporting Functions and Variables

### Exporting Variables
```bash
# Export variables for child processes
export MY_VARIABLE="value"
export PATH="/custom/path:$PATH"

# Export with default values
export LOG_FILE="${LOG_FILE:-/var/log/default.log}"
```

### Exporting Functions (Bash-specific)
```bash
# Define and export a function
my_function() {
    echo "Hello from shared function"
}
export -f my_function

# Export multiple functions
export -f function1 function2 function3
```

### Example: GPS Utilities Export
```bash
# gps_utils.sh - GPS-specific utility functions

# Define functions
check_gps_device() {
    local device="${1:-/dev/serial0}"
    [ -e "$device" ] && echo "GPS device found: $device"
}

configure_gpsd() {
    echo "Configuring GPSD..."
    # Configuration logic here
}

# Export functions for other scripts
export -f check_gps_device
export -f configure_gpsd

# Export variables
export GPS_DEFAULT_DEVICE="/dev/serial0"
export GPS_DEFAULT_BAUDRATE="9600"
```

## Configuration Files

### Configuration File Format
```bash
# gpsberry.conf - Configuration file example
# Format: KEY=VALUE (no spaces around =)

# GPS Hardware
GPS_DEVICE=/dev/serial0
GPS_BAUDRATE=9600

# GPSD Settings
GPSD_ENABLED=true
GPSD_OPTIONS=-n

# Logging
LOG_FILE=/var/log/gps/gpsberry.log
LOG_LEVEL=INFO
```

### Loading Configuration Files
```bash
# Using the shared load_config function
load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Clean up key and value
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs | sed 's/^["'\'']\|["'\'']$//g')
            
            # Export with CONFIG_ prefix
            export "CONFIG_$key"="$value"
        done < "$config_file"
        echo "✓ Configuration loaded from: $config_file"
    fi
}

# Usage
load_config "/path/to/config.conf"
echo "Device: $CONFIG_GPS_DEVICE"
```

## Best Practices

### 1. Use Fallback Functions
Provide fallback implementations in case shared utilities aren't available:

```bash
# Load shared utilities
if [ -f "$UTILS_PATH" ]; then
    source "$UTILS_PATH"
else
    # Fallback functions
    print_info() { echo "ℹ  $@"; }
    print_error() { echo "✗ $@"; }
fi
```

### 2. Check Function Availability
Test if functions exist before using them:

```bash
if command -v shared_function >/dev/null 2>&1; then
    shared_function "parameter"
else
    echo "Shared function not available, using fallback"
    local_function "parameter"
fi
```

### 3. Use Consistent Naming
- Configuration variables: `CONFIG_VARIABLE_NAME`
- Exported functions: `descriptive_function_name`
- Shared utilities: `utils.sh`, `gps_utils.sh`, etc.

### 4. Document Dependencies
```bash
#!/bin/bash
# Dependencies:
# - ../essentials/utils.sh (shared utilities)
# - ./gps_utils.sh (GPS-specific functions)
# - ./gpsberry.conf (configuration file)
```

### 5. Handle Missing Dependencies Gracefully
```bash
# Check for required dependencies
check_dependencies() {
    local missing=0
    
    if [ ! -f "$UTILS_PATH" ]; then
        echo "⚠ Missing: $UTILS_PATH"
        ((missing++))
    fi
    
    if [ $missing -gt 0 ]; then
        echo "Warning: $missing dependencies missing"
        echo "Some features may not be available"
    fi
    
    return $missing
}
```

## Examples

### Example 1: Simple Function Sharing
```bash
# File: shared_functions.sh
greet() {
    echo "Hello, $1!"
}
export -f greet

# File: main_script.sh
source ./shared_functions.sh
greet "World"  # Output: Hello, World!
```

### Example 2: Configuration-Driven Script
```bash
#!/bin/bash
# main_script.sh

# Load configuration
CONFIG_FILE="./app.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Use configuration variables with defaults
DATABASE_HOST="${DATABASE_HOST:-localhost}"
DATABASE_PORT="${DATABASE_PORT:-5432}"

echo "Connecting to $DATABASE_HOST:$DATABASE_PORT"
```

### Example 3: Modular GPS Script
```bash
#!/bin/bash
# gps_main.sh

# Load all dependencies
source "../essentials/utils.sh"      # General utilities
source "./gps_utils.sh"              # GPS-specific functions
load_config "./gpsberry.conf"        # Configuration

# Use shared functions
if check_gps_device "$CONFIG_GPS_DEVICE"; then
    print_success "GPS device ready"
    configure_gpsd_daemon "$CONFIG_GPS_DEVICE"
else
    print_error "GPS device not found"
    exit 1
fi
```

### Example 4: Creating a Library Script
```bash
#!/bin/bash
# math_utils.sh - Reusable math functions

add() {
    echo $(($1 + $2))
}

multiply() {
    echo $(($1 * $2))
}

# Export all functions
export -f add multiply

# If run directly, show available functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Math utilities library"
    echo "Available functions: add, multiply"
    echo "Usage: source math_utils.sh"
fi
```

### Example 5: Environment Setup Script
```bash
#!/bin/bash
# setup_env.sh - Environment configuration

# Set common paths
export PROJECT_ROOT="/opt/raspberry-config"
export LOG_DIR="$PROJECT_ROOT/logs"
export CONFIG_DIR="$PROJECT_ROOT/config"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Set common functions
setup_logging() {
    local component="$1"
    local log_file="$LOG_DIR/${component}.log"
    echo "Logging for $component: $log_file"
    # Setup log rotation, etc.
}

export -f setup_logging

echo "Environment setup complete"
echo "PROJECT_ROOT: $PROJECT_ROOT"
echo "LOG_DIR: $LOG_DIR"
echo "CONFIG_DIR: $CONFIG_DIR"
```

## Project Structure for Sharing

```
raspberry-config/
├── essentials/
│   ├── utils.sh              # General utilities
│   └── install_essentials.sh
├── gps-berry/
│   ├── gps_utils.sh          # GPS-specific utilities
│   ├── gpsberry.conf         # GPS configuration
│   ├── gpsberry_install.sh   # Main installer (uses utils.sh)
│   ├── post-reboot.sh        # Post-install (uses both)
│   └── gps_management.sh     # Management tool
└── shared/
    ├── config/               # Shared configuration files
    ├── lib/                  # Shared library scripts
    └── templates/            # Configuration templates
```

## Summary

1. **Use `source` to import**: Load functions and variables from other scripts
2. **Export with `export -f`**: Make functions available to child processes
3. **Use configuration files**: Store settings in separate files
4. **Provide fallbacks**: Handle missing dependencies gracefully
5. **Document dependencies**: Make it clear what scripts need
6. **Test availability**: Check if functions exist before using them
7. **Use consistent naming**: Make it easy to understand what's shared

This approach makes your scripts more modular, maintainable, and reusable across the entire raspberry-config project.
